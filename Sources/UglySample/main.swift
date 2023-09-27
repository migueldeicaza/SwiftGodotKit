//
//  main.swift
//
// This sample is ugly because it is convenient for me to test and try things out,
// and this is definitely not how you should write your code, it is just a big ball
// of messy things that are useful for me when debugging.
//
//  SwiftGodotKit Sample
//
//  Created by Miguel de Icaza on 4/1/23.
//

import Foundation
import SwiftGodot
import SwiftGodotKit

func loadProject (settings: ProjectSettings) {
    //var notset = Variant("Not Set")
    //var value = settings.getSetting(name: "display/window/vsync/vsync_mode", defaultValue: notset)
    //print ("Got: \(value)")
}

func loadScene (scene: SceneTree) {
    let a = GString ("Hello GString")
    print ("Created a GString, and rendering as a Swift String: \(a.description)")
    let sn = StringName(stringLiteral: "Hello StringName")
    print ("Created a StringName, and rendering as a Swift String: \(sn.description)")


    let rootNode = Node3D()
    let camera = Camera3D ()
    camera.current = true
    camera.position = Vector3(x: 0, y: 0, z: 2)
    
    rootNode.addChild(node: camera)
    for node in rootNode.getChildren() {
        print ("rootNode's node is a: \(node)")
    }

    func makeCuteNode (_ pos: Vector3) -> Node {
        let n = SpinningCube()
        n.position = pos
        return n
    }
    rootNode.addChild(node: makeCuteNode(Vector3(x: 1, y: 1, z: 1)))
    rootNode.addChild(node: makeCuteNode(Vector3(x: -1, y: -1, z: -1)))
    rootNode.addChild(node: makeCuteNode(Vector3(x: 0, y: 1, z: 1)))
    scene.root?.addChild(node: rootNode)
    let timer = scene.createTimer (timeSec: 3)
    Task {
        let start = Date ()
        await timer?.timeout.emitted
        let ended = Date ()
        
        print ("Timer compelted! in \(ended.timeIntervalSince(start))")
    }
    for node in rootNode.getChildren() {
        print ("rootNode's node is a \(node)")
        let r = GD.absf(x: -10)
        
        print (r)
    }
    
    print ("ClassList:")
    let r = ClassDB.shared.getClassList()
    for x in r {
        print ("   classItem: \(x)")
    }
    
}

@Godot
class Demo: Node3D {
    @Export var count: Int = 3
    @Callable
    func performCuteOperation (x: Int, s: String) -> Resource? {
        return nil
    }
}

class SpinningCube: Node3D {
    static let myFirstSignal = StringName ("MyFirstSignal")
    static let printerSignal = StringName ("PrinterSignal")
    
    static var initClass: Bool = {
        // This registers the signal
        let s = ClassInfo<SpinningCube>(name: "SpinningCube")
        s.registerSignal(name: SpinningCube.myFirstSignal, arguments: [])
        
        let printArgs = [
            PropInfo(
                propertyType: .string,
                propertyName: StringName ("myArg"),
                className: "SpinningCube",
                hint: .flags,
                hintStr: "Text",
                usage: .propertyUsageDefault)
        ]
        
        let x = Vector2(x: 10, y: 10)
        let y = x * Int64 (24)
        
        s.registerSignal(name: SpinningCube.printerSignal, arguments: printArgs)
        
        let f = SpinningCube.MyCallback
        s.registerMethod(name: "MyCallback", flags: .default, returnValue: nil, arguments: [], function: SpinningCube.MyCallback)
        
        s.registerMethod(name: "MyPrinter", flags: .default, returnValue: nil, arguments: printArgs, function: SpinningCube.MyPrinter)
        s.registerMethod(name: "readyCallback", flags: .default, returnValue: nil, arguments: printArgs, function: SpinningCube.readyCallback)
        return true
    }()
    
    required init (nativeHandle: UnsafeRawPointer) {
        super.init (nativeHandle: nativeHandle)
    }
    
    required init () {
        super.init ()
        let meshRender = MeshInstance3D()
        meshRender.mesh = BoxMesh()
        addChild(node: meshRender)
        
        _ = SpinningCube.initClass
        
        // This shows how to connect to a signal in this case
        // the one we defined here, but I am pointing it to another
        // object (the mesh) and saying "call demo" - which is wrong, but
        // wont be flagged until the event is emitted.
        print (connect(signal: SpinningCube.myFirstSignal, callable: Callable(object: self, method: StringName ("MyCallback"))))
        print (connect(signal: SpinningCube.printerSignal, callable: Callable(object: self, method: StringName ("MyPrinter"))))
        print (connect(signal: StringName ("ready"), callable: Callable (object: self, method: StringName ("readyCallback"))))
        let r = ready.connect {
            print ("READY INVOKED")
        }
    }
    
        private func testMesh() {
                let mesh = BoxMesh()
                mesh.size = Vector3(x: 2, y: 2, z: 2)
                let meshInstance = MeshInstance3D()
                meshInstance.mesh = mesh
                self.addChild(node: meshInstance)
            }
    
    override func _input (event: InputEvent) {
        guard event.isPressed () && !event.isEcho () else { return }
        print ("SpinningCube: event: isPressed ")
    }
    
    func readyCallback (args: [Variant]) -> Variant? {
        print ("SpinningCube: readyCallback method called")
        return nil
        
    }
    
    func MyCallback (args: [Variant]) -> Variant? {
        print ("SpinningCube: MySignal triggered")
        return nil
    }

    func MyPrinter (args: [Variant]) -> Variant? {
        guard args.count > 0 else {
            print ("SpinningCube: Not enough parameters to MyPrinter: \(args.count)")
            return nil
        }
        guard let v = GString (args [0]) else {
            print ("SpinningCube: No string in vararg")
            return nil
        }
        print ("SpinningCube.MyPrinter, got string payload \(v.description)")
        return nil
    }

    public override func _ready() {
        testMesh()
    }
    public override func _process(delta: Double) {
        rotateY(angle: delta)
        // Here we emit the signal, but due to the wrong bindnig above,
        // it will print an error
        let emitMyFirstSignalResult = emitSignal(SpinningCube.myFirstSignal)
        print ("emitMyFirstSignalResult: \(emitMyFirstSignalResult)")
        let emitMyPrinterSignalResult = emitSignal(SpinningCube.printerSignal, Variant (GString ("Delta is: \(delta)")))
        print ("emitMyPrinterSignalResult: \(emitMyPrinterSignalResult)")
    }
}

class Another: Node3D {
    override func _ready() {
        testMesh ()
        testArray ()
    }

    func testArray ()
    {
        print ("Testing the other case")
        let gArray = GArray()
              gArray.pushBack(value: Variant("Hello"))
              let value = gArray[Int(0)]
              GD.print("\(value)")
        

    }
    private func testMesh() {
        let mesh = BoxMesh()
        mesh.size = Vector3(x: 2, y: 2, z: 2)
        let meshInstance = MeshInstance3D()
        meshInstance.mesh = mesh
        meshInstance.name = "TestName"
        self.addChild(node: meshInstance, forceReadableName: true)
    }

    
}
func registerTypes (level: GDExtension.InitializationLevel) {
    print ("Registering level: \(level)")
    switch level {
    case .scene:
        register (type: Another.self)
    default:
        break
    }
}

func loadTwo (scene: SceneTree) {
    let rootNode = Node3D()
    rootNode.addChild(node: Another ())
    scene.root?.addChild(node: rootNode)
}

runGodot(args: [], initHook: registerTypes, loadScene: loadTwo, loadProjectSettings: loadProject)
