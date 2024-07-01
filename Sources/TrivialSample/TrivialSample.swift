
import Foundation
import SwiftGodot
import SwiftGodotKit
import SwiftUI

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

struct ContentView: View {
    
    func trivial(){
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
        // scene.root?.addChild(node: rootNode)
    }


    @StateObject var host = GodotSceneHost(scene: "main.pck", godotPackPath: "/tmp")
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            HStack {
                GodotAppView()
                VStack {
                    GodotWindow { sub in
                        
                    }
                    GodotWindow { sub in
                        
                    }
                    GodotWindow { sub in
                    }
                }
            }
        }
        .padding()
        .environmentObject(host)
    }
}

#Preview {
    ContentView()
}
