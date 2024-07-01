//
//  GodotApp.swift
//
//

import SwiftUI
import SwiftGodot

/// The GodotSceneHost loads a single scene from a Godot pack file, when the scene is
/// created, the `instance` field will be set to a value.
public class GodotSceneHost: ObservableObject {
    let path: String
    let renderingDriver: String
    let renderingMethod: String
    let extraArgs: [String]
    let maxTouchCount = 32
    #if os(iOS)
    var touches: [UITouch?] = []
    #endif
    
    /// The Godot instance for this host, if it was successfully created
    public var instance: GodotInstance?
  
    /// Initializes Godot to render a scene.
    /// - Parameters:
    ///  - scene: the name of the scene file, usually something like "game.pck"
    ///  - godotPackPath: the directory where a scene can be created from, if it is not
    /// provided, this will try the `Bundle.main.resourcePath` directory, and if that is nil,
    /// then current "." directory will be used as the basis
    ///  - renderingDriver: the name of the Godot driver to use, defaults to `vulkan`
    ///  - renderingMethod: the Godot rendering method to use, defaults to `mobile`
    public init (
        scene: String,
        godotPackPath: String? = nil,
        renderingDriver: String = "vulkan",
        renderingMethod: String = "mobile",
        extraArgs: [String] = []
    ) {
        let dir = godotPackPath ?? Bundle.main.resourcePath ?? "."
        path = "\(dir)/\(scene)"
        self.renderingDriver = renderingDriver
        self.renderingMethod = renderingMethod
        self.extraArgs = extraArgs
    }
    
    @discardableResult
    func start() -> Bool {
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
//            #if os(macOS)
//            "--display-driver", "embedded"
//            #else
            "--display-driver", "macos"
        ]
        args.append(contentsOf: extraArgs)
       
        
        instance = GodotInstance.create(args: args)
        return instance != nil
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
