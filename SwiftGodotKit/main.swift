//
//  main.swift
//  SwiftGodotKit Sample
//
//  Created by Miguel de Icaza on 4/1/23.
//

import Foundation
import SwiftGodot


func loadProject (settings: ProjectSettings) {
}

func loadScene (scene: SceneTree) {
    let a = GString ("Hello GString")
    print ("Got: \(a.description)")
    let sn = StringName(stringLiteral: "Hello StringName")
    print ("Got: \(sn.description)")

    let rootNode = Node3D()
    let camera = Camera3D ()
    camera.current = true
    camera.position = Vector3(x: 0, y: 0, z: 2)
    
    rootNode.addChild(node: camera)
    
    func makeCuteNode (_ pos: Vector3) -> Node {
        let n = SpinningCube()
        n.position = pos
        return n
    }
    rootNode.addChild(node: makeCuteNode(Vector3(x: 1, y: 1, z: 1)))
    rootNode.addChild(node: makeCuteNode(Vector3(x: -1, y: -1, z: -1)))
    rootNode.addChild(node: makeCuteNode(Vector3(x: 0, y: 1, z: 1)))
    scene.root.addChild(node: rootNode)
}


class SpinningCube: Node3D {
    required init () {
        super.init ()
        let meshRender = MeshInstance3D()
        meshRender.mesh = BoxMesh()
        addChild(node: meshRender)
    }
    public override func _process(delta: Double) {
        rotateY(angle: delta)
    }
}

func registerTypes (level: GDExtension.InitializationLevel) {
    print ("Registering level: \(level)")
    switch level {
    case .scene:
        register (type: SpinningCube.self)
    default:
        break
    }
}

runGodot(args: [], initHook: registerTypes, loadScene: loadScene, loadProjectSettings: loadProject)
