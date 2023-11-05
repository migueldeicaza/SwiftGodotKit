//
//  Created by Miguel de Icaza on 4/1/23.
//

import Foundation
import SwiftGodot
import SwiftGodotKit

func loadScene (scene: SceneTree) {
   let rootNode = Node3D()
    let camera = Camera3D ()
    camera.current = true
    camera.position = Vector3(x: 0, y: 0, z: 2)
    
    rootNode.addChild(node: camera)

    
    scene.root?.addChild(node: rootNode)
}



func registerTypes (level: GDExtension.InitializationLevel) {
    GD.printerr(arg1: Variant ("hello"))
    
    switch level {
    case .scene:
        register (type: SpinningCube.self)
    default:
        break
    }
}

runGodot(args: [], initHook: registerTypes, loadScene: loadScene, loadProjectSettings: { settings in })
