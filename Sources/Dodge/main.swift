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
    scene.changeSceneToFile (path: "res://Main.tscn")
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

runGodot(args: [], initHook: registerTypes, loadScene: loadScene, loadProjectSettings: { settings in })
