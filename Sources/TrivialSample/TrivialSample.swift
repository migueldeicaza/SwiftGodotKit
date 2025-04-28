
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
    init() {
        initHookCb = { level in
            if level == .scene {
                register(type: SpinningCube.self)
            }
        }
    }

    func trivial() -> Node3D {
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

        return rootNode
    }

    var extraViews: some View {
        VStack {
            GodotWindow { sub in
                let ctr = VBoxContainer()
                ctr.setAnchorsPreset(Control.LayoutPreset.fullRect)
                sub.addChild(node: ctr)

                let button1 = Button()
                button1.text = "SubWindow 1"
                let button2 = Button()
                button2.text = "Another Button"
                ctr.addChild(node: button1)
                ctr.addChild(node: button2)
            }
            GodotWindow { sub in
                let ctr = VBoxContainer()
                ctr.setAnchorsPreset(Control.LayoutPreset.fullRect)
                sub.addChild(node: ctr)

                let button1 = Button()
                button1.text = "SubWindow 2"
                let button2 = Button()
                button2.text = "Another Button 2"
                ctr.addChild(node: button1)
                ctr.addChild(node: button2)
            }
            GodotWindow { sub in
                let ctr = VBoxContainer()
                ctr.setAnchorsPreset(Control.LayoutPreset.fullRect)
                sub.addChild(node: ctr)

                let button1 = Button()
                button1.text = "SubWindow 3"
                let button2 = Button()
                button2.text = "Another Button 3"
                ctr.addChild(node: button1)
                ctr.addChild(node: button2)
            }
            GodotWindow { sub in
                sub.addChild(node: trivial())
            }
        }
    }

    @State var app = GodotApp(packFile: "main.pck", godotPackPath: "/tmp")

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            HStack {
                GodotAppView()
                extraViews

            }
        }
        .padding()
        .environment(\.godotApp, app)
        .onAppear {
            app.start()
            print ("GodotApp: Started")
        }
    }
}

#Preview {
    ContentView()
}
