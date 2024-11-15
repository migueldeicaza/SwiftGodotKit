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
    guard let name = from ["name"]?.description else { return nil }
    guard let type = Int (from ["type"] ?? Variant (Nil())) else { return nil }
    guard let className = from ["class_name"]?.description else { return nil }
    guard let hint = Int (from ["hint"] ?? Variant (Nil())) else { return nil }
    guard let hint_string = from ["hint_string"]?.description else { return nil }
    guard let usage = Int (from ["usage"] ?? Variant (Nil())) else { return nil }
    return PropInfo(propertyType: Variant.GType(rawValue: Int64(type))!,
                    propertyName: StringName(stringLiteral: name),
                    className: StringName (stringLiteral: className),
                    hint: PropertyHint (rawValue: Int64(hint))!,
                    hintStr: GString (stringLiteral: hint_string),
                    usage: PropertyUsageFlags(rawValue: Int(usage)))
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
        
    for dict in properties {
        guard let p = propInfo(from: dict) else {
            print ("Failed to load \(dict)")
            continue
        }
        if p.usage.contains(.group) {
            print ("GROUP: \(p.propertyName)")
            continue
        } else if p.usage.contains(.subgroup) {
            print ("Subgroup: \(p.hintStr)")
        } else if p.usage.contains(.category) {
            print ("Category")
        } else {
            let prefix: String
            if p.usage == [] {
                prefix = "SKIP: "
                continue
            } else {
                prefix = ""
            }
            let hintStr: String
            if p.hintStr != "" {
                hintStr = "hintStr=\(p.hintStr)"
            } else {
                hintStr = ""
            }
            print ("    \(prefix)name=\(p.propertyName)/\(p.className) type=\(p.propertyType) hint=\(p.hint) \(hintStr) usage=\(p.usage)")
        }
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
    rootNode.addChild(node: makeCuteNode(Vector3(x: -1, y: -1, z: -1)))
    rootNode.addChild(node: makeCuteNode(Vector3(x: 0, y: 1, z: 1)))
    scene.root?.addChild(node: rootNode)
}


@Godot
class SpinningCube: Node3D {
    public override func _ready() {
        let meshRender = MeshInstance3D()
        meshRender.mesh = BoxMesh()
        addChild(node: meshRender)
    }
    
    override func _input (event: InputEvent) {
        switch event {
        case let mouseEvent as InputEventMouseButton:
            print("MouseButton: \(mouseEvent)")
        case let mouseMotion as InputEventMouseMotion:
            print("MouseMotion: \(mouseMotion)")
        default:
            print (event)
        }        
        
        guard event.isPressed () && !event.isEcho () else { return }
        print ("SpinningCube: event: isPressed ")
    }
    
    public override func _process(delta: Double) {
        rotateY(angle: delta)
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
