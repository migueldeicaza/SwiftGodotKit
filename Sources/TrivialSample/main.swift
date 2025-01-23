//
//  main.swift
//
// Very trivial example of using SwiftGodotKit
//
//  Created by Miguel de Icaza on 4/1/23.
//

import Foundation
import SwiftGodot
import SwiftGodotKit

//extension GArray: Sequence {
//    public struct GArrayIterator: IteratorProtocol {
//        public mutating func next() -> SwiftGodot.Variant? {
//            idx += 1
//            if idx < a.size() {
//                return a[idx]
//            }
//            return nil
//        }
//        
//        public typealias Element = Variant
//        
//        let a: GArray
//        var idx = -1
//        
//        init (_ a: GArray) {
//            self.a = a
//        }
//    }
//    public func makeIterator() -> GArrayIterator {
//        return GArrayIterator (self)
//    }
//}

func propInfo (from: GDictionary) -> PropInfo? {
    return nil
}

func loadScene (scene: SceneTree) {
    let properties = ClassDB.classGetPropertyList (class: StringName ("Node2D"))
    print ("Elements: \(properties.count)")
    let a = GArray()
    a.append(Variant ("Hello"))
    a.append(Variant ("Word"))
    a.append(Variant ("Foo"))
    for x in a {
        print ("value is \(x)")
    }


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
//    rootNode.addChild(node: makeCuteNode(Vector3(x: -1, y: -1, z: -1)))
//    rootNode.addChild(node: makeCuteNode(Vector3(x: 0, y: 1, z: 1)))
    scene.root?.addChild(node: rootNode)
}

class Demo {
    init() {
        print("Demo.Starting")
    }
    func call() {
        print("Alive")
    }
    deinit{
        print("Demo.Finishing")
    }
}

@Godot
class SpinningCube: Node3D {
    var obj = Node3D()
    var c: Callable?

    deinit {
        print("Killing Spinning Cube")
    }
    public override func _ready() {
        let meshRender = MeshInstance3D()
        meshRender.mesh = BoxMesh()
        let v = Variant(meshRender)
        var x = Object(v)
        addChild(node: meshRender)

        var xx = Button()
        var d = Demo()
        c = Callable { args in
            print("calling demo")
            d.call()
            print ("In callable!")
            return nil
        }
    }
    
//    override func _input (event: InputEvent) {
//        switch event {
//        case let mouseEvent as InputEventMouseButton:
//            print("MouseButton: \(mouseEvent)")
//        case let mouseMotion as InputEventMouseMotion:
//            print("MouseMotion: \(mouseMotion)")
//        default:
//            print (event)
//        }        
//        
//        guard event.isPressed () && !event.isEcho () else { return }
//        print ("SpinningCube: event: isPressed ")
//    }

    var count = 0
    public override func _process(delta: Double) {
        rotateY(angle: delta)
        count += 1
        if count == 1 {
            print ("Going to kill myself")
            queueFree()
        }
        //print ("IsValid after free: \(obj.isValid)")
        if let c {
            c.call()
        }
        c = nil
    }
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
