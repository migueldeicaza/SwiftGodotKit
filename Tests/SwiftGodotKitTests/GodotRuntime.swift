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
    
    static func run(completion: @escaping () -> Void) {
        guard !isRunning else { return }
        runGodot(args: [], initHook: { level in
            switch level {
            case .scene:
                completion()
            default:
                break
            }
        }, loadScene: { scene in
            self.scene = scene
        }, loadProjectSettings: { settings in
            self.settings = settings
        })
    }
    
    static func stop() {
        scene?.quit()
    }
    
}
