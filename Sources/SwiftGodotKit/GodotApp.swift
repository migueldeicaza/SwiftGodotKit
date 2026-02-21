//
//  GodotApp.swift
//
//

import SwiftUI
import SwiftGodot
import Foundation
import OSLog
#if os(iOS)
import UIKit
#endif

/// You create a single Godot App per application, this contains your game PCK
@Observable
public class GodotApp: ObservableObject {
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
        var args: [String] = []
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                args.append(contentsOf: ["--path", path])
            } else {
                args.append(contentsOf: ["--main-pack", path])
            }
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
        args.append(contentsOf: extraArgs)
        Logger.App.info("GodotApp.start path=\(self.path, privacy: .public)")
        Logger.App.info("GodotApp.start args=\(args.joined(separator: " "), privacy: .public)")
        
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
        
        return true
    }

    public func stop() {
        guard let instance else { return }
        Logger.App.info("GodotApp.stop destroying GodotInstance")
        GodotInstance.destroy(instance: instance)
        self.instance = nil
        isPaused = false
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

    public func runOnGodotThread(async: Bool = true, _ block: @escaping () -> Void) {
        guard let instance else {
            Logger.App.error("runOnGodotThread called before Godot instance was created")
            return
        }
        _ = async
        // Godot 4.6 embedded mode currently crashes inside SwiftGodot's `execute`
        // trampoline (`GodotInstance.method_execute`) on focus/lifecycle callbacks.
        // Run callbacks directly until execute binding compatibility is restored.
        if instance.isStarted() {
            block()
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
