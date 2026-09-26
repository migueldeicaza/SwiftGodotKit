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
        guard let app, app.isEngineRunning else { return false }
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

private final class WeakObject<Value: AnyObject> {
    weak var value: Value?

    init(_ value: Value) { self.value = value }
}

/// The result of asking `GodotApp` to create its native instance.
/// Engine startup finishes later, after a view supplies a native surface.
public enum GodotAppStartResult {
    case created
    case alreadyCreated
    /// Creation, engine startup or a stop is in progress. The call cancels
    /// a pending stop request. During a stop, the engine does not start
    /// again when the stop completes. Call `start()` again after that.
    case inProgress
    case scheduled
    case processBusy
    case failed
    case stopped
}

/// The result of a stop request. A deferred stop needs a successful engine
/// start before the current libgodot binary can destroy its instance.
public enum GodotAppStopResult {
    case stopped
    case deferred
    case scheduled
    case alreadyStopped
    case startupFailed
}

/// The current state of the process-wide Godot lifecycle owned by this app.
public enum GodotAppLifecycleState: Equatable {
    case idle
    case creating
    case initialized
    case stopPending
    case preparingSurface
    case starting
    case running
    case stopping
    case failed
}

private final class LifecycleSnapshot {
    private let lock = NSLock()
    private var state: GodotAppLifecycleState = .idle
    private var currentInstance: GodotInstance?
    private var running = false
    private var pendingStop = false

    func publish(
        state: GodotAppLifecycleState,
        instance: GodotInstance?,
        running: Bool,
        pendingStop: Bool
    ) {
        lock.lock()
        let previousInstance = currentInstance
        self.state = state
        currentInstance = instance
        self.running = running
        self.pendingStop = pendingStop
        lock.unlock()
        withExtendedLifetime(previousInstance) {}
    }

    func readState() -> GodotAppLifecycleState {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    func readInstance() -> GodotInstance? {
        lock.lock()
        defer { lock.unlock() }
        return currentInstance
    }

    func isRunning() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return running
    }

    func hasPendingStop() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return pendingStop
    }
}

/// You create a single Godot App per application, this contains your game PCK
@Observable
public class GodotApp: ObservableObject {
    @ObservationIgnored private static var processOwner: GodotApp?
    @ObservationIgnored private static var nativeProcessUnavailable = false
    @ObservationIgnored private var startup = StartupCoordinator<GodotInstance>()
    @ObservationIgnored private let lifecycleSnapshot = LifecycleSnapshot()
    private var lifecycleRevision: UInt64 = 0
    @ObservationIgnored private var startupView: TTGodotAppView?
    @ObservationIgnored private var stopRequested = false {
        didSet {
            if oldValue != stopRequested { publishLifecycle() }
        }
    }
    @ObservationIgnored private var drainingStarts = false
    @ObservationIgnored private var engineOperationDepth = 0
    @ObservationIgnored private var knownViews: [ObjectIdentifier: WeakObject<TTGodotAppView>] = [:]
    @ObservationIgnored private var knownWindows: [ObjectIdentifier: WeakObject<TTGodotWindow>] = [:]
    let path: String
    let renderingDriver: String
    let renderingMethod: String
    let displayDriver: String
    let extraArgs: [String]
    let maxTouchCount = 32
    @ObservationIgnored private var pendingStart = SnapshotQueue<TTGodotAppView>()
    @ObservationIgnored private var pendingLayout = SnapshotQueue<TTGodotAppView>()
    @ObservationIgnored private var pendingWindow = SnapshotQueue<TTGodotWindow>()

    #if os(macOS)
    internal let appDelegate: GodotAppDelegate
    #endif

    #if os(iOS)
    @ObservationIgnored var touches: [UITouch?] = []
    @ObservationIgnored private var lifecycleObservers: [NSObjectProtocol] = []
    #endif
    
    /// The Godot instance for this host, if it was successfully created.
    /// This getter does not wait for the main thread. Use the returned
    /// instance on the main thread, and use `GodotApp` for lifecycle calls.
    public var instance: GodotInstance? {
        if Thread.isMainThread { _ = lifecycleRevision }
        return lifecycleSnapshot.readInstance()
    }
    public var lifecycleState: GodotAppLifecycleState {
        if Thread.isMainThread { _ = lifecycleRevision }
        return lifecycleSnapshot.readState()
    }
    /// True when `stop()` will wait for startup or an active engine call.
    public var isStopPending: Bool {
        if Thread.isMainThread { _ = lifecycleRevision }
        return lifecycleSnapshot.hasPendingStop()
    }
    var isEngineRunning: Bool { lifecycleSnapshot.isRunning() }
    @ObservationIgnored public private(set) var isPaused = false
    @ObservationIgnored public private(set) var isDrawing = true
    @ObservationIgnored private var hostBridge: SwiftGodotHostBridge?
    @ObservationIgnored private var callbacks: [UUID: ViewCallback] = [:]
    @ObservationIgnored private var runtimeEventHandlers: [UUID: (GodotAppEvent) -> Void] = [:]
    @ObservationIgnored private let runtimeEventHandlersLock = NSLock()
    @ObservationIgnored private var launchSourceOverride: String?
    @ObservationIgnored private var launchSceneOverride: String?
    @ObservationIgnored private var nextViewId: Int64 = 1
    @ObservationIgnored private var lifecycleHasFocus = true
    @ObservationIgnored private var lifecycleIsPaused = false

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
    ///  - renderingDriver: the name of the Godot driver to use. The default is `metal` on devices and macOS, and `opengl3` in the iOS Simulator.
    ///  - renderingMethod: the Godot rendering method to use. The default is `mobile` on devices and macOS, and `gl_compatibility` in the iOS Simulator.
    ///  - displayDriver: the Godot display driver, defaults to `embedded`
    public init (
        packFile: String,
        godotPackPath: String? = nil,
        renderingDriver: String? = nil,
        renderingMethod: String? = nil,
        displayDriver: String = "embedded",
        extraArgs: [String] = []
    ) {
        let dir = godotPackPath ?? Bundle.main.resourcePath ?? "."
        path = "\(dir)/\(packFile)"
        #if os(iOS) && targetEnvironment(simulator)
        self.renderingDriver = renderingDriver ?? "opengl3"
        self.renderingMethod = renderingMethod ?? "gl_compatibility"
        #else
        self.renderingDriver = renderingDriver ?? "metal"
        self.renderingMethod = renderingMethod ?? "mobile"
        #endif
        self.displayDriver = displayDriver
        self.extraArgs = extraArgs
        
        #if os(macOS)
        self.appDelegate = GodotAppDelegate()
        self.appDelegate.app = self
        #endif

        #if os(iOS)
        registerLifecycleObservers()
        switch UIApplication.shared.applicationState {
        case .active:
            lifecycleHasFocus = true
            lifecycleIsPaused = false
        case .background:
            lifecycleHasFocus = false
            lifecycleIsPaused = true
        case .inactive:
            lifecycleHasFocus = false
            lifecycleIsPaused = false
        @unknown default:
            lifecycleHasFocus = false
            lifecycleIsPaused = false
        }
        #endif

        startup.onPhaseChange = { [weak self] in
            self?.publishLifecycle()
        }
    }

    private func publishLifecycle() {
        precondition(Thread.isMainThread)
        let state: GodotAppLifecycleState
        switch startup.phase {
        case .idle: state = .idle
        case .creating: state = .creating
        case .initialized: state = stopRequested ? .stopPending : .initialized
        case .preparing: state = .preparingSurface
        case .starting: state = .starting
        case .running: state = .running
        case .stopping: state = .stopping
        case .failed: state = .failed
        }
        lifecycleSnapshot.publish(
            state: state,
            instance: startup.instance,
            running: startup.isRunning,
            pendingStop: stopRequested
        )
        lifecycleRevision &+= 1
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
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.startPending() }
            return
        }
        guard instance != nil, !drainingStarts else { return }
        drainingStarts = true
        pendingStart.drain { view in
            if view.app === self && view.isAttachedForStartup {
                view.startGodotInstance()
            }
        }
        drainingStarts = false

        guard isEngineRunning else { return }
        performEngineOperation {
            pendingLayout.drain { view in
                guard view.app === self && view.isAttachedForStartup else { return }
#if os(macOS)
                view.needsLayout = true
#else
                view.setNeedsLayout()
#endif
            }
            drainPendingWindows()
        }
        if !pendingStart.isEmpty {
            DispatchQueue.main.async { [weak self] in self?.startPending() }
        }
    }

    /// Returns true when this call creates or finds an initialized instance.
    /// A call made during startup or from a background thread returns false.
    /// Use `startResult()` to distinguish queued work from a failure.
    @discardableResult
    public func start() -> Bool {
        switch startResult() {
        case .created, .alreadyCreated: return true
        case .inProgress, .scheduled, .processBusy, .failed, .stopped: return false
        }
    }

    /// Creates the native instance, or reports why it did not.
    /// See `GodotAppStartResult` for the meaning of each result.
    @discardableResult
    public func startResult() -> GodotAppStartResult {
        if !Thread.isMainThread {
            DispatchQueue.main.async { _ = self.startResult() }
            return .scheduled
        }
        switch startup.beginCreation() {
        case .alreadyCreated:
            stopRequested = false
            if isPaused {
                resume()
            }
            return .alreadyCreated
        case .inProgress:
            stopRequested = false
            return .inProgress
        case .failed:
            return .failed
        case .create:
            break
        }
        if Self.nativeProcessUnavailable {
            startup.completeCreation(nil)
            emitStartupFailure(.nativeProcessUnavailable)
            return .failed
        }
        if let owner = Self.processOwner, owner !== self {
            startup.cancelCreation()
            emitStartupFailure(.processBusy)
            return .processBusy
        }
        Self.processOwner = self

        #if os(iOS)
        touches = [UITouch?](repeating: nil, count: maxTouchCount)
        #endif
        let scene = normalizedScene(launchSceneOverride)
        let sourcePath = normalizedPath(launchSourceOverride) ?? path
        guard let startupSource = validateStartupSource(sourcePath: sourcePath, scene: scene) else {
            startup.cancelCreation()
            releaseProcessOwnership()
            stopRequested = false
            return .failed
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
        let godotDisplayDriver = self.displayDriver
        if godotDisplayDriver == "embedded" {
            args.append("--embedded")
        }
        #elseif os(iOS)
        let godotDisplayDriver = self.displayDriver == "embedded" ? "iOS" : self.displayDriver
        #else
        let godotDisplayDriver = self.displayDriver
        #endif
        args.append(contentsOf: [
            "--display-driver", godotDisplayDriver
        ])
        if let scene {
            args.append(scene)
        }
        args.append(contentsOf: extraArgs)
        Logger.App.info("GodotApp.start path=\(self.path, privacy: .public)")
        Logger.App.info("GodotApp.start args=\(args.joined(separator: " "), privacy: .public)")

        ensureHostBridgeTypeRegistration()
        
        let createdInstance = GodotInstance.create(args: args)
        if createdInstance == nil { Self.nativeProcessUnavailable = true }
        startup.completeCreation(createdInstance)
        guard let instance = createdInstance else {
            Logger.App.error("GodotApp.start failed to create GodotInstance")
            releaseProcessOwnership()
            emitStartupFailure(.instanceCreationFailed)
            clearPendingWork()
            stopRequested = false
            return .failed
        }
        isPaused = false
        Logger.App.info("GodotApp.start created instance. isStarted=\(instance.isStarted())")
        
#if os(macOS)
        NSApplication.shared.delegate = appDelegate
#endif

        startPending()
        if startup.isFailed { return .failed }
        if startup.isIdle { return .stopped }
        return .created
    }

    /// Stops a running engine. A request during startup waits until startup
    /// succeeds.
    @discardableResult
    public func stop() -> GodotAppStopResult {
        if !Thread.isMainThread {
            DispatchQueue.main.async { _ = self.stop() }
            return .scheduled
        }
        if engineOperationDepth > 0 {
            stopRequested = true
            return .deferred
        }
        switch startup.beginStop() {
        case .deferUntilReady, .needsEngineStart:
            // Main::cleanup is unsafe before native engine startup completes.
            stopRequested = true
            return .deferred
        case .alreadyStopped:
            return .alreadyStopped
        case .failed:
            return .startupFailed
        case .destroy(let instance):
            destroyInstance(instance)
            return .stopped
        }
    }

    private func destroyInstance(_ instance: GodotInstance) {
        Logger.App.info("GodotApp.stop destroying GodotInstance")
        if hostBridge != nil {
            emitRuntimeEvent(.bridge(GodotBridgeEvent(state: .detached)))
        }
        let windows = Array(knownWindows.values)
        for window in windows { window.value?.engineWillStop() }
        GodotInstance.destroy(instance: instance)
        let views = Array(knownViews.values)
        for view in views { view.value?.engineDidStop() }
        startupView?.engineDidStop()
        clearPendingWork()
        knownViews.removeAll()
        knownWindows.removeAll()
        for id in Array(callbacks.keys) {
            guard var callback = callbacks[id] else { continue }
            callback.didSendReady = false
            callbacks[id] = callback
        }
        startupView = nil
        stopRequested = false
        self.hostBridge = nil
        isPaused = false
        isDrawing = true
        startup.finishStop()
        releaseProcessOwnership()
    }

    private func releaseProcessOwnership() {
        if Self.processOwner === self { Self.processOwner = nil }
    }

    private func clearPendingWork() {
        pendingStart.removeAll()
        pendingLayout.removeAll()
        pendingWindow.removeAll()
    }

    private func emitStartupFailure(_ reason: GodotStartupFailureEvent.Reason) {
        emitRuntimeEvent(.startupFailure(GodotStartupFailureEvent(
            reason: reason,
            sourcePath: normalizedPath(launchSourceOverride) ?? path,
            scene: normalizedScene(launchSceneOverride)
        )))
    }

    public func pause() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.pause() }
            return
        }
        guard isEngineRunning, let instance else { return }
        if !isPaused {
            performEngineOperation {
                instance.pause()
                isPaused = true
            }
        }
    }

    public func resume() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.resume() }
            return
        }
        guard isEngineRunning, let instance else { return }
        if isPaused {
            performEngineOperation {
                instance.resume()
                isPaused = false
            }
        }
    }

    public func startDrawing() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.startDrawing() }
            return
        }
        isDrawing = true
    }

    public func stopDrawing() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.stopDrawing() }
            return
        }
        isDrawing = false
    }

    /// Runs the block on the main thread when the engine is running.
    /// From a background thread, this method queues the block and returns,
    /// even when `async` is `false`. Do not read the block's result after
    /// this method returns from a background thread.
    public func runOnGodotThread(async: Bool = true, _ block: @escaping () -> Void) {
        guard instance != nil else {
            Logger.App.error("runOnGodotThread called before Godot instance was created")
            emitRuntimeEvent(
                .warning(
                    GodotWarningEvent(
                        code: .runOnGodotThreadBeforeInstance,
                        detail: "runOnGodotThread called before Godot instance was created"
                    )
                )
            )
            return
        }
        guard isEngineRunning else { return }

        let invoke = { [weak self] in
            guard let self, self.isEngineRunning else { return }
            self.performEngineOperation(block)
        }

        if Thread.isMainThread {
            invoke()
            return
        }

        if !async {
            Logger.App.warning("runOnGodotThread cannot run synchronously from a background thread; scheduling on the main thread")
        }
        DispatchQueue.main.async(execute: invoke)
    }

    #if os(iOS)
    private func registerLifecycleObservers() {
        let center = NotificationCenter.default
        let didBecomeActive = center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applicationDidBecomeActive()
        }

        let willResignActive = center.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applicationDidResignActive()
        }

        let didEnterBackground = center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applicationDidEnterBackground()
        }

        let willEnterForeground = center.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applicationWillEnterForeground()
        }

        lifecycleObservers = [didBecomeActive, willResignActive, didEnterBackground, willEnterForeground]
    }
    #endif

    func applicationDidBecomeActive() {
        if isEngineRunning, let instance {
            performEngineOperation { instance.focusIn() }
        }
        resume()
        setApplicationFocus(true)
    }

    func applicationDidResignActive() {
        if isEngineRunning, let instance {
            performEngineOperation { instance.focusOut() }
        }
        pause()
        setApplicationFocus(false)
    }

    #if os(iOS)
    func applicationDidEnterBackground() {
        setApplicationPaused(true)
    }

    func applicationWillEnterForeground() {
        setApplicationPaused(false)
    }
    #endif

    private func setApplicationFocus(_ focused: Bool) {
        guard lifecycleHasFocus != focused else { return }
        lifecycleHasFocus = focused
        let notification = Int32(focused ? MainLoop.notificationApplicationFocusIn : MainLoop.notificationApplicationFocusOut)
        postMainLoopNotification(notification, label: focused ? "focus_in" : "focus_out")
    }

    private func setApplicationPaused(_ paused: Bool) {
        guard lifecycleIsPaused != paused else { return }
        lifecycleIsPaused = paused
        let notification = Int32(paused ? MainLoop.notificationApplicationPaused : MainLoop.notificationApplicationResumed)
        postMainLoopNotification(notification, label: paused ? "paused" : "resumed")
    }

    private func postMainLoopNotification(_ notification: Int32, label: String) {
        guard isEngineRunning else { return }
        emitRuntimeEvent(.lifecycle(GodotLifecycleEvent(label: label, notification: notification)))
        runOnGodotThread {
            Engine.getMainLoop()?.notification(what: notification)
            Logger.App.debug("MainLoop notification \(label, privacy: .public) (\(notification))")
        }
    }

    enum ViewStartupAction {
        case prepare
        case running
        case wait
        case failed
    }

    func beginViewStartup(_ view: TTGodotAppView) -> ViewStartupAction {
        precondition(Thread.isMainThread)
        guard view.app === self else { return .failed }
        knownViews[ObjectIdentifier(view)] = WeakObject(view)
        guard view.isAttachedForStartup else {
            queueStart(view)
            return .wait
        }
        switch startup.beginViewStartup() {
        case .prepare:
            startupView = view // Retain the selected surface through native start.
            return .prepare
        case .running:
            return .running
        case .wait:
            queueStart(view)
            return .wait
        case .failed:
            return .failed
        }
    }

    func completeSurfacePreparation(for view: TTGodotAppView, succeeded: Bool) -> Bool {
        precondition(Thread.isMainThread)
        guard startupView === view else { return false }
        guard let instance = startup.finishSurfacePreparation(
            succeeded: succeeded && view.isAttachedForStartup
        ) else {
            startupView = nil
            return false
        }

        let started = instance.start()
        if !started { Self.nativeProcessUnavailable = true }
        startup.finishEngineStart(succeeded: started)
        if !started {
            Logger.App.error("GodotApp failed to start the engine")
            // Keep the native wrapper alive. The published binary has no
            // proven cleanup path after a failed engine start.
            emitStartupFailure(.engineStartFailed)
            clearPendingWork()
            stopRequested = false
            return false
        }
        if stopRequested {
            stop()
            return false
        }
        let viewIsAttached = view.isAttachedForStartup
        if viewIsAttached { startupView = nil }
        DispatchQueue.main.async { [weak self] in
            self?.startPending()
            self?.pollBridgeAndReadiness()
        }
        return viewIsAttached
    }

    func runningViewDidBindSurface(_ view: TTGodotAppView) {
        guard isEngineRunning, view.isAttachedForStartup else { return }
        if startupView !== view { startupView = nil }
    }

    func queueStart(_ godotAppView: TTGodotAppView) {
        guard !startup.isFailed else { return }
        pendingStart.insert(godotAppView)
    }

    func removePending(_ godotAppView: TTGodotAppView) {
        pendingStart.remove(godotAppView)
        pendingLayout.remove(godotAppView)
        knownViews.removeValue(forKey: ObjectIdentifier(godotAppView))
        if startupView === godotAppView {
            // Keep the selected view alive until the synchronous native call
            // returns. A new view can bind its surface after that call.
            return
        }
    }

    func queueLayout(_ godotAppView: TTGodotAppView) {
        guard !startup.isFailed else { return }
        pendingLayout.insert(godotAppView)
    }

    func queueGodotWindow(_ godotWindow: TTGodotWindow) {
        guard !startup.isFailed else { return }
        knownWindows[ObjectIdentifier(godotWindow)] = WeakObject(godotWindow)
        pendingWindow.insert(godotWindow)
    }

    func registerGodotWindow(_ godotWindow: TTGodotWindow) {
        knownWindows[ObjectIdentifier(godotWindow)] = WeakObject(godotWindow)
    }

    func removePending(_ godotWindow: TTGodotWindow) {
        pendingWindow.remove(godotWindow)
        knownWindows.removeValue(forKey: ObjectIdentifier(godotWindow))
    }

    public func configureLaunch(source: String? = nil, scene: String? = nil) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.configureLaunch(source: source, scene: scene)
            }
            return
        }
        if !startup.isIdle {
            let normalizedSource = normalizedPath(source)
            let normalizedScene = normalizedScene(scene)
            if launchSourceOverride != normalizedSource || launchSceneOverride != normalizedScene {
                Logger.App.error("Ignoring source/scene change because Godot startup is active or failed")
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

    @discardableResult
    public func registerEventHandler(_ handler: @escaping (GodotAppEvent) -> Void) -> UUID {
        let id = UUID()
        runtimeEventHandlersLock.lock()
        runtimeEventHandlers[id] = handler
        runtimeEventHandlersLock.unlock()
        return id
    }

    public func unregisterEventHandler(_ id: UUID?) {
        guard let id else { return }
        runtimeEventHandlersLock.lock()
        runtimeEventHandlers[id] = nil
        runtimeEventHandlersLock.unlock()
    }

    func emitRuntimeEvent(_ event: GodotAppEvent) {
        let dispatch = { [weak self] in
            guard let self else { return }
            self.runtimeEventHandlersLock.lock()
            let handlers = Array(self.runtimeEventHandlers.values)
            self.runtimeEventHandlersLock.unlock()
            guard !handlers.isEmpty else { return }
            for handler in handlers {
                handler(event)
            }
        }

        if Thread.isMainThread {
            dispatch()
        } else {
            DispatchQueue.main.async(execute: dispatch)
        }
    }

    func pollBridgeAndReadiness() {
        guard isEngineRunning else { return }
        performEngineOperation {
            drainPendingWindows()
            _ = ensureHostBridgeAttached()
            notifyReadyIfPossible()
        }
    }

    @discardableResult
    func performEngineOperation<Result>(_ body: () -> Result) -> Result {
        beginEngineOperation()
        defer { endEngineOperation() }
        return body()
    }

    func beginEngineOperation() {
        precondition(Thread.isMainThread)
        engineOperationDepth += 1
    }

    func endEngineOperation() {
        precondition(Thread.isMainThread && engineOperationDepth > 0)
        engineOperationDepth -= 1
        if engineOperationDepth == 0 && stopRequested && isEngineRunning {
            stop()
        }
    }

    private func drainPendingWindows() {
        guard !pendingWindow.isEmpty else { return }
        pendingWindow.drain { window in
            window.initGodotWindow()
        }
    }

    public func emitMessage(_ message: VariantDictionary, from viewId: Int64? = nil) {
        runOnGodotThread { [weak self] in
            guard let self, let bridge = self.ensureHostBridgeAttached() else { return }
            let payload = VariantDictionary(from: message)
            if let viewId {
                payload[BridgeRouting.viewIdKey] = Variant(viewId)
            }
            bridge.receiveMessageFromHost(message: payload)
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
            isEngineRunning,
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
        let targetViewId = BridgeRouting.routedViewId(from: message)
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

    private func ensureHostBridgeAttached() -> SwiftGodotHostBridge? {
        guard isEngineRunning else { return nil }
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
            emitRuntimeEvent(.bridge(GodotBridgeEvent(state: .attachedExisting)))
            return existing
        }

        let bridge = SwiftGodotHostBridge()
        bridge.name = StringName(SwiftGodotHostBridge.nodeName)
        bridge.onMessageToHost = { [weak self] message in
            self?.broadcastMessage(message)
        }
        root.addChild(node: bridge)
        hostBridge = bridge
        emitRuntimeEvent(.bridge(GodotBridgeEvent(state: .attachedCreated)))
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
            emitRuntimeEvent(
                .startupFailure(
                    GodotStartupFailureEvent(
                        reason: .sourcePathMissing,
                        sourcePath: sourcePath,
                        scene: scene
                    )
                )
            )
            return nil
        }

        if isDirectory.boolValue {
            let projectFile = sourcePath + "/project.godot"
            guard FileManager.default.fileExists(atPath: projectFile) else {
                Logger.App.error("GodotApp.start failed: missing project.godot in source directory: \(sourcePath, privacy: .public)")
                emitRuntimeEvent(
                    .startupFailure(
                        GodotStartupFailureEvent(
                            reason: .projectFileMissing,
                            sourcePath: sourcePath,
                            scene: scene
                        )
                    )
                )
                return nil
            }

            let cacheFile = sourcePath + "/.godot/global_script_class_cache.cfg"
            if !FileManager.default.fileExists(atPath: cacheFile) {
                Logger.App.warning("GodotApp.start warning: missing global script cache at \(cacheFile, privacy: .public). Godot will need to rebuild cache.")
                emitRuntimeEvent(
                    .warning(
                        GodotWarningEvent(
                            code: .globalScriptCacheMissing,
                            detail: "Missing global script cache at \(cacheFile). Godot will rebuild cache."
                        )
                    )
                )
            }

            if let scene, let scenePath = resolveScenePathForValidation(scene: scene, sourceDirectory: sourcePath) {
                guard FileManager.default.fileExists(atPath: scenePath) else {
                    Logger.App.error("GodotApp.start failed: scene does not exist: \(scenePath, privacy: .public)")
                    emitRuntimeEvent(
                        .startupFailure(
                            GodotStartupFailureEvent(
                                reason: .sceneMissing,
                                sourcePath: sourcePath,
                                scene: scene
                            )
                        )
                    )
                    return nil
                }
            }

            return .directory(sourcePath)
        }

        if let scene {
            if scene.hasPrefix("/") {
                if !FileManager.default.fileExists(atPath: scene) {
                    Logger.App.error("GodotApp.start failed: absolute scene path does not exist: \(scene, privacy: .public)")
                    emitRuntimeEvent(
                        .startupFailure(
                            GodotStartupFailureEvent(
                                reason: .sceneMissing,
                                sourcePath: sourcePath,
                                scene: scene
                            )
                        )
                    )
                    return nil
                }
            } else if scene.hasPrefix("file://"), let scenePath = normalizedPath(scene), !FileManager.default.fileExists(atPath: scenePath) {
                Logger.App.error("GodotApp.start failed: file scene path does not exist: \(scenePath, privacy: .public)")
                emitRuntimeEvent(
                    .startupFailure(
                        GodotStartupFailureEvent(
                            reason: .sceneMissing,
                            sourcePath: sourcePath,
                            scene: scene
                        )
                    )
                )
                return nil
            } else if !scene.hasPrefix("res://") && !scene.contains("://") {
                Logger.App.warning("GodotApp.start warning: scene '\(scene, privacy: .public)' is relative while launching from a pack file; validation is limited.")
                emitRuntimeEvent(
                    .warning(
                        GodotWarningEvent(
                            code: .limitedSceneValidation,
                            detail: "Scene '\(scene)' is relative while launching from a pack file; validation is limited."
                        )
                    )
                )
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
            emitRuntimeEvent(
                .warning(
                    GodotWarningEvent(
                        code: .skippedSceneValidationUri,
                        detail: "Skipping filesystem validation for scene URI: \(scene)"
                    )
                )
            )
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
