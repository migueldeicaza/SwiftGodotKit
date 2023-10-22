//
//  GodotRuntime.swift
//
//
//  Created by Mikhail Tishin on 22.10.2023.
//

import SwiftGodot
import SwiftGodotKit

final class GodotRuntime {
    
    static var isRunning: Bool = false
    
    static var scene: SceneTree?
    static var settings: ProjectSettings?
    
    static func run (completion: @escaping () -> Void) {
        guard !isRunning else { return }
        isRunning = true
        runGodot (args: [], initHook: { level in
        }, loadScene: { scene in
            self.scene = scene
            completion()
        }, loadProjectSettings: { settings in
            self.settings = settings
        })
    }
    
    static func stop() {
        isRunning = false
        scene?.quit ()
    }
    
}
