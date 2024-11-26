//
//  GodotApp.swift
//
//

import SwiftUI
import SwiftGodot

/// You create a single Godot App per application, this contains your game PCK
public class GodotApp: ObservableObject {
    let path: String
    let renderingDriver: String
    let renderingMethod: String
    let extraArgs: [String]
    let maxTouchCount = 32
    var pendingStart = Set<TTGodotAppView>()
    var pendingLayout = Set<TTGodotAppView>()
    var pendingWindow = Set<TTGodotWindow>()

    #if os(iOS)
    var touches: [UITouch?] = []
    #endif
    
    /// The Godot instance for this host, if it was successfully created
    public var instance: GodotInstance?
  
    /// Initializes Godot to render a scene.
    /// - Parameters:
    ///  - packFile: the name of the pack file in the godotPackPath.
    ///  - godotPackPath: the directory where a scene can be created from, if it is not
    /// provided, this will try the `Bundle.main.resourcePath` directory, and if that is nil,
    /// then current "." directory will be used as the basis
    ///  - renderingDriver: the name of the Godot driver to use, defaults to `vulkan`
    ///  - renderingMethod: the Godot rendering method to use, defaults to `mobile`
    public init (
        packFile: String,
        godotPackPath: String? = nil,
        renderingDriver: String = "metal",
        renderingMethod: String = "mobile",
        extraArgs: [String] = []
    ) {
        let dir = godotPackPath ?? Bundle.main.resourcePath ?? "."
        path = "\(dir)/\(packFile)"
        self.renderingDriver = renderingDriver
        self.renderingMethod = renderingMethod
        self.extraArgs = extraArgs

    }

    public func startPending() {
        guard let instance else { return }

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
            return true
        }
        #if os(iOS)
        touches = [UITouch?](repeating: nil, count: maxTouchCount)
        #endif
        var args = [
            "--main-pack", path,
            "--rendering-driver", renderingDriver,
            "--rendering-method", renderingMethod,
            "--display-driver", "embedded"
        ]
        args.append(contentsOf: extraArgs)
        
        instance = GodotInstance.create(args: args)
        startPending()
        
        return instance != nil
    }

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
