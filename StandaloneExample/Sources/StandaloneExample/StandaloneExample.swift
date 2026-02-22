import SwiftUI
import SwiftGodot
import SwiftGodotKit

@Godot
class SpinningCube: Node3D {
    public override func _ready() {
        let meshRender = MeshInstance3D()
        meshRender.mesh = BoxMesh()
        addChild(node: meshRender)
    }

    public override func _process(delta: Double) {
        rotateY(angle: delta)
    }
}

private func loadScene(scene: SceneTree) {
    let rootNodeName = StringName("__standalone_example_root__")
    if scene.root?.findChild(pattern: rootNodeName.description, recursive: false, owned: false) != nil {
        return
    }

    let rootNode = Node3D()
    rootNode.name = rootNodeName

    let camera = Camera3D()
    camera.current = true
    camera.position = Vector3(x: 0, y: 0, z: 2)
    rootNode.addChild(node: camera)

    func makeCube(_ pos: Vector3) -> Node {
        let cube = SpinningCube()
        cube.position = pos
        return cube
    }

    rootNode.addChild(node: makeCube(Vector3(x: 1, y: 1, z: 1)))
    rootNode.addChild(node: makeCube(Vector3(x: -1, y: -1, z: -1)))
    rootNode.addChild(node: makeCube(Vector3(x: 0, y: 1, z: 1)))
    scene.root?.addChild(node: rootNode)
}

struct ContentView: View {
    #if os(macOS)
    @State private var app = GodotApp(
        packFile: "",
        godotPackPath: Bundle.main.bundlePath,
        displayDriver: ProcessInfo.processInfo.environment["GODOT_DISPLAY_DRIVER"] ?? "embedded"
    )
    #else
    @State private var app = GodotApp(packFile: "main.pck", godotPackPath: Bundle.main.bundlePath)
    #endif

    init() {
        initHookCb = { level in
            if level == .scene {
                register(type: SpinningCube.self)
            }
        }
    }

    var body: some View {
        GodotAppView(
            onReady: { _ in
                app.runOnGodotThread(async: true) {
                    guard let scene = Engine.getMainLoop() as? SceneTree else { return }
                    loadScene(scene: scene)
                }
            }
        )
        .frame(minWidth: 800, minHeight: 600)
        .environment(\.godotApp, app)
        .onAppear {
            app.start()
        }
    }
}

@main
struct StandaloneExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
