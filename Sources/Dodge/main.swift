//
//  File.swift
//  
//
//  Created by Miguel de Icaza on 1/6/24.
//

import Foundation
import SwiftGodotKit
import SwiftGodot

func loadScene (scene: SceneTree) {
}

func registerTypes (level: GDExtension.InitializationLevel) {
    switch level {
    case .scene:
        register (type: Hud.self)
        register (type: Mob.self)
        register (type: Player.self)
        register (type: Main.self)
    default:
        break
    }
}

guard let projectPath = Bundle.module.path(forResource: "Project", ofType: nil) else {
    fatalError("Could not load resource path")
}

//runGodot(args: ["--path", projectPath], initHook: registerTypes, loadScene: loadScene, loadProjectSettings: { settings in })
