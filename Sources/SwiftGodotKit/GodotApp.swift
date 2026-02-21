//
//  GodotApp.swift
//
//

import SwiftUI
import SwiftGodot
import Foundation
import OSLog
#if canImport(Dispatch)
import Dispatch
#endif
#if os(iOS)
import UIKit
#endif

public final class GodotAppViewHandle {
    private weak var app: GodotApp?
    fileprivate var viewId: Int64?

    internal init(app: GodotApp) {
        self.app = app
    }

    public func pause() {
        app?.pause()
    }

    public func resume() {
        app?.resume()
    }

    public func getRoot() -> Node? {
        guard let sceneTree = Engine.getMainLoop() as? SceneTree else { return nil }
        return sceneTree.root
    }

    public func isReady() -> Bool {
        guard let app, let instance = app.instance, instance.isStarted() else { return false }
        return getRoot() != nil
    }

    public func emitMessage(_ message: VariantDictionary) {
        app?.emitMessage(message, from: viewId)
    }

    public func startDrawing() {
        app?.startDrawing()
    }

    public func stopDrawing() {
        app?.stopDrawing()
    }
}

private struct ViewCallback {
    let handle: GodotAppViewHandle
    let viewId: Int64
    let onReady: ((GodotAppViewHandle) -> Void)?
    let onMessage: ((VariantDictionary) -> Void)?
    var didSendReady = false
}

/// You create a single Godot App per application, this contains your game PCK
@Observable
public class GodotApp: ObservableObject {
    private enum BridgeRouting {
        static let viewIdKey = "__swiftgodotkit_view_id"
    }

    let path: String
    let renderingDriver: String
    let renderingMethod: String
    let displayDriver: String
    let extraArgs: [String]
    let maxTouchCount = 32
    @ObservationIgnored var pendingStart = Set<TTGodotAppView>()
    @ObservationIgnored var pendingLayout = Set<TTGodotAppView>()
    @ObservationIgnored var pendingWindow = Set<TTGodotWindow>()

    #if os(macOS)
    internal let appDelegate: GodotAppDelegate
    #endif

    #if os(iOS)
    @ObservationIgnored var touches: [UITouch?] = []
    @ObservationIgnored private var lifecycleObservers: [NSObjectProtocol] = []
    #endif
    
    /// The Godot instance for this host, if it was successfully created
    @ObservationIgnored public var instance: GodotInstance?
    @ObservationIgnored public private(set) var isPaused = false
    @ObservationIgnored public private(set) var isDrawing = true
    @ObservationIgnored private var hostBridge: SwiftGodotHostBridge?
    @ObservationIgnored private var callbacks: [UUID: ViewCallback] = [:]
    @ObservationIgnored private var launchSourceOverride: String?
    @ObservationIgnored private var launchSceneOverride: String?
    @ObservationIgnored private var nextViewId: Int64 = 1

    private enum StartupSource {
        case directory(String)
        case packFile(String)
    }

    /// Initializes Godot to render a scene.
    /// - Parameters:
    ///  - packFile: the name of the pack file in the godotPackPath.
    ///  - godotPackPath: the directory where a scene can be created from, if it is not
    /// provided, this will try the `Bundle.main.resourcePath` directory, and if that is nil,
    /// then current "." directory will be used as the basis
    ///  - renderingDriver: the name of the Godot driver to use, defaults to `vulkan`
    ///  - renderingMethod: the Godot rendering method to use, defaults to `mobile`
    ///  - displayDriver: the Godot display driver, defaults to `embedded`
    public init (
        packFile: String,
        godotPackPath: String? = nil,
        renderingDriver: String = "metal",
        renderingMethod: String = "mobile",
        displayDriver: String = "embedded",
        extraArgs: [String] = []
    ) {
        let dir = godotPackPath ?? Bundle.main.resourcePath ?? "."
        path = "\(dir)/\(packFile)"
        self.renderingDriver = renderingDriver
        self.renderingMethod = renderingMethod
        self.displayDriver = displayDriver
        self.extraArgs = extraArgs
        
        #if os(macOS)
        self.appDelegate = GodotAppDelegate()
        self.appDelegate.app = self
        #endif

        #if os(iOS)
        registerLifecycleObservers()
        #endif
    }

    deinit {
        #if os(iOS)
        for observer in lifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        lifecycleObservers.removeAll()
        #endif
    }

    public func startPending() {
        guard instance != nil else { return }

        for view in pendingStart {
            view.startGodotInstance()
        }
        pendingStart.removeAll()

        for view in pendingLayout {
#if os(macOS)
            view.needsLayout = true
#else
            view.setNeedsLayout()
#endif
        }
        pendingLayout.removeAll()

        for window in pendingWindow {
            window.initGodotWindow()
        }
        pendingWindow.removeAll()   
    }

    @discardableResult
    public func start() -> Bool {
        if instance != nil {
            if isPaused {
                resume()
            }
            return true
        }

        #if os(iOS)
        touches = [UITouch?](repeating: nil, count: maxTouchCount)
        #endif
        let scene = normalizedScene(launchSceneOverride)
        let sourcePath = normalizedPath(launchSourceOverride) ?? path
        guard let startupSource = validateStartupSource(sourcePath: sourcePath, scene: scene) else {
            return false
        }

        var args: [String] = []
        switch startupSource {
        case .directory(let directory):
            args.append(contentsOf: ["--path", directory])
        case .packFile(let packFile):
            args.append(contentsOf: ["--main-pack", packFile])
        }
        args.append(contentsOf: [
            "--rendering-driver", renderingDriver,
            "--rendering-method", renderingMethod
        ])
        #if os(macOS)
        if self.displayDriver == "embedded" {
            args.append("--embedded")
        }
        #endif
        args.append(contentsOf: [
            "--display-driver", self.displayDriver
        ])
        if let scene {
            args.append(scene)
        }
        args.append(contentsOf: extraArgs)
        Logger.App.info("GodotApp.start path=\(self.path, privacy: .public)")
        Logger.App.info("GodotApp.start args=\(args.joined(separator: " "), privacy: .public)")

        ensureHostBridgeTypeRegistration()
        
        instance = GodotInstance.create(args: args)
        guard let instance else {
            Logger.App.error("GodotApp.start failed to create GodotInstance")
            return false
        }
        isPaused = false
        Logger.App.info("GodotApp.start created instance. isStarted=\(instance.isStarted())")
        
#if os(macOS)
        NSApplication.shared.delegate = appDelegate
#endif

        startPending()
        pollBridgeAndReadiness()
        
        return true
    }

    public func stop() {
        guard let instance else { return }
        Logger.App.info("GodotApp.stop destroying GodotInstance")
        GodotInstance.destroy(instance: instance)
        self.instance = nil
        self.hostBridge = nil
        isPaused = false
        isDrawing = true
    }

    public func pause() {
        guard let instance else { return }
        if !isPaused {
            instance.pause()
            isPaused = true
        }
    }

    public func resume() {
        guard let instance else { return }
        if isPaused {
            instance.resume()
            isPaused = false
        }
    }

    public func startDrawing() {
        isDrawing = true
    }

    public func stopDrawing() {
        isDrawing = false
    }

    public func runOnGodotThread(async: Bool = true, _ block: @escaping () -> Void) {
        guard let instance else {
            Logger.App.error("runOnGodotThread called before Godot instance was created")
            return
        }
        guard instance.isStarted() else { return }

        let invoke = { [weak self] in
            guard let self, let instance = self.instance, instance.isStarted() else { return }
            block()
        }

        if Thread.isMainThread {
            invoke()
            return
        }

        if async {
            DispatchQueue.main.async(execute: invoke)
        } else {
            DispatchQueue.main.sync(execute: invoke)
        }
    }

    #if os(iOS)
    private func registerLifecycleObservers() {
        let center = NotificationCenter.default
        let didBecomeActive = center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.instance?.focusIn()
            self?.resume()
        }

        let willResignActive = center.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.instance?.focusOut()
            self?.pause()
        }

        lifecycleObservers = [didBecomeActive, willResignActive]
    }
    #endif

    func queueStart(_ godotAppView: TTGodotAppView) {
        pendingStart.insert(godotAppView)
    }

    func queueLayout(_ godotAppView: TTGodotAppView) {
        pendingLayout.insert(godotAppView)
    }

    func queueGodotWindow(_ godotWindow: TTGodotWindow) {
        pendingWindow.insert(godotWindow)
    }

    public func configureLaunch(source: String? = nil, scene: String? = nil) {
        if instance != nil {
            let normalizedSource = normalizedPath(source)
            let normalizedScene = normalizedScene(scene)
            if launchSourceOverride != normalizedSource || launchSceneOverride != normalizedScene {
                Logger.App.error("Ignoring source/scene change because GodotApp is already started")
            }
            return
        }
        launchSourceOverride = normalizedPath(source)
        launchSceneOverride = normalizedScene(scene)
    }

    @discardableResult
    func registerViewCallbacks(
        handle: GodotAppViewHandle,
        onReady: ((GodotAppViewHandle) -> Void)?,
        onMessage: ((VariantDictionary) -> Void)?
    ) -> UUID {
        let viewId = nextViewId
        nextViewId += 1
        handle.viewId = viewId

        let id = UUID()
        callbacks[id] = ViewCallback(handle: handle, viewId: viewId, onReady: onReady, onMessage: onMessage)
        notifyReadyIfPossible(for: id)
        return id
    }

    func unregisterViewCallbacks(id: UUID?) {
        guard let id else { return }
        callbacks[id] = nil
    }

    func pollBridgeAndReadiness() {
        _ = ensureHostBridgeAttached()
        notifyReadyIfPossible()
    }

    public func emitMessage(_ message: VariantDictionary, from viewId: Int64? = nil) {
        runOnGodotThread { [weak self] in
            guard let self, let bridge = self.ensureHostBridgeAttached() else { return }
            let payload = VariantDictionary(from: message)
            if let viewId {
                payload[BridgeRouting.viewIdKey] = Variant(viewId)
            }
            bridge.messageFromHost.emit(payload)
        }
    }

    private func notifyReadyIfPossible() {
        for id in callbacks.keys {
            notifyReadyIfPossible(for: id)
        }
    }

    private func notifyReadyIfPossible(for id: UUID) {
        guard
            var callback = callbacks[id],
            !callback.didSendReady,
            let instance,
            instance.isStarted(),
            let sceneTree = Engine.getMainLoop() as? SceneTree,
            sceneTree.root != nil
        else {
            return
        }
        callback.didSendReady = true
        callbacks[id] = callback
        if let onReady = callback.onReady {
            let handle = callback.handle
            DispatchQueue.main.async {
                onReady(handle)
            }
        }
    }

    private func broadcastMessage(_ message: VariantDictionary) {
        let targetViewId = routedViewId(from: message)
        let messageCallbacks = callbacks.values.compactMap { callback -> ((VariantDictionary) -> Void)? in
            guard targetViewId == nil || callback.viewId == targetViewId else {
                return nil
            }
            return callback.onMessage
        }
        guard !messageCallbacks.isEmpty else { return }

        DispatchQueue.main.async {
            for onMessage in messageCallbacks {
                onMessage(message)
            }
        }
    }

    private func routedViewId(from message: VariantDictionary) -> Int64? {
        if let value = Int64(message[BridgeRouting.viewIdKey]) {
            return value
        }
        if let text = String(message[BridgeRouting.viewIdKey]), let value = Int64(text) {
            return value
        }
        return nil
    }

    private func ensureHostBridgeAttached() -> SwiftGodotHostBridge? {
        guard let instance, instance.isStarted() else { return nil }
        guard let sceneTree = Engine.getMainLoop() as? SceneTree, let root = sceneTree.root else {
            return nil
        }

        if let hostBridge, hostBridge.getParent() != nil {
            return hostBridge
        }

        if let existing = root.findChild(pattern: SwiftGodotHostBridge.nodeName) as? SwiftGodotHostBridge {
            existing.onMessageToHost = { [weak self] message in
                self?.broadcastMessage(message)
            }
            hostBridge = existing
            return existing
        }

        let bridge = SwiftGodotHostBridge()
        bridge.name = StringName(SwiftGodotHostBridge.nodeName)
        bridge.onMessageToHost = { [weak self] message in
            self?.broadcastMessage(message)
        }
        root.addChild(node: bridge)
        hostBridge = bridge
        return bridge
    }

    private func normalizedPath(_ source: String?) -> String? {
        guard let source, !source.isEmpty else { return nil }
        if source.hasPrefix("file://"), let url = URL(string: source), url.isFileURL {
            return url.path
        }
        return source
    }

    private func normalizedScene(_ scene: String?) -> String? {
        guard let scene, !scene.isEmpty else { return nil }
        return scene
    }

    private func validateStartupSource(sourcePath: String, scene: String?) -> StartupSource? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: sourcePath, isDirectory: &isDirectory) else {
            Logger.App.error("GodotApp.start failed: source path does not exist: \(sourcePath, privacy: .public)")
            return nil
        }

        if isDirectory.boolValue {
            let projectFile = sourcePath + "/project.godot"
            guard FileManager.default.fileExists(atPath: projectFile) else {
                Logger.App.error("GodotApp.start failed: missing project.godot in source directory: \(sourcePath, privacy: .public)")
                return nil
            }

            let cacheFile = sourcePath + "/.godot/global_script_class_cache.cfg"
            if !FileManager.default.fileExists(atPath: cacheFile) {
                Logger.App.warning("GodotApp.start warning: missing global script cache at \(cacheFile, privacy: .public). Godot will need to rebuild cache.")
            }

            if let scene, let scenePath = resolveScenePathForValidation(scene: scene, sourceDirectory: sourcePath) {
                guard FileManager.default.fileExists(atPath: scenePath) else {
                    Logger.App.error("GodotApp.start failed: scene does not exist: \(scenePath, privacy: .public)")
                    return nil
                }
            }

            return .directory(sourcePath)
        }

        if let scene {
            if scene.hasPrefix("/") {
                if !FileManager.default.fileExists(atPath: scene) {
                    Logger.App.error("GodotApp.start failed: absolute scene path does not exist: \(scene, privacy: .public)")
                    return nil
                }
            } else if scene.hasPrefix("file://"), let scenePath = normalizedPath(scene), !FileManager.default.fileExists(atPath: scenePath) {
                Logger.App.error("GodotApp.start failed: file scene path does not exist: \(scenePath, privacy: .public)")
                return nil
            } else if !scene.hasPrefix("res://") && !scene.contains("://") {
                Logger.App.warning("GodotApp.start warning: scene '\(scene, privacy: .public)' is relative while launching from a pack file; validation is limited.")
            }
        }

        return .packFile(sourcePath)
    }

    private func resolveScenePathForValidation(scene: String, sourceDirectory: String) -> String? {
        if scene.hasPrefix("res://") {
            let suffix = String(scene.dropFirst("res://".count))
            return sourceDirectory + "/" + suffix
        }
        if scene.hasPrefix("file://") {
            return normalizedPath(scene)
        }
        if scene.hasPrefix("/") {
            return scene
        }
        if scene.contains("://") {
            Logger.App.warning("GodotApp.start warning: skipping filesystem validation for scene URI: \(scene, privacy: .public)")
            return nil
        }
        return sourceDirectory + "/" + scene
    }

    #if os(iOS)
    func getTouchId(touch: UITouch) -> Int {
        var first = -1
        for i in 0 ... maxTouchCount - 1 {
            if first == -1 && touches[i] == nil {
                first = i;
                continue;
            }
            if (touches[i] == touch) {
                return i;
            }
        }

        if (first != -1) {
            touches[first] = touch;
            return first;
        }

        return -1;
    }

    func removeTouchId(id: Int) {
        touches[id] = nil
    }
    #endif
}

public extension EnvironmentValues {
    @Entry var godotApp: GodotApp? = nil
}
