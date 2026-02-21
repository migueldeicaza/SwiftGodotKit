
import Foundation
import SwiftGodot
import SwiftGodotKit
import SwiftUI

private func sampleLog(_ message: String) {
    if let data = ("[TrivialSample] \(message)\n").data(using: .utf8) {
        FileHandle.standardError.write(data)
    }
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

@Godot
class DynamicNamedWindowSpawner: Node {
    static let spawnerNodeName = "__dynamic_named_window_spawner__"
    static let windowNodeName = "__dynamic_named_window__"

    private var elapsed: Double = 0
    private var showingWindow = false
    private var generation: Int64 = 0

    public override func _ready() {
        setProcess(enable: true)
        createWindowIfNeeded()
        sampleLog("DynamicNamedWindowSpawner ready")
    }

    public override func _process(delta: Double) {
        elapsed += delta
        if elapsed < 2.5 {
            return
        }
        elapsed = 0

        if showingWindow {
            destroyWindowIfPresent()
        } else {
            createWindowIfNeeded()
        }
    }

    private func sceneRoot() -> Node? {
        (Engine.getMainLoop() as? SceneTree)?.root
    }

    private func createWindowIfNeeded() {
        guard let root = sceneRoot() else { return }
        if root.findChild(pattern: Self.windowNodeName, recursive: true, owned: false) is SwiftGodot.Window {
            showingWindow = true
            return
        }

        generation += 1
        let window = SwiftGodot.Window()
        window.name = StringName(Self.windowNodeName)
        window.title = "Lifecycle Probe \(generation)"
        window.size = Vector2i(x: 520, y: 190)

        let container = VBoxContainer()
        container.setAnchorsPreset(Control.LayoutPreset.fullRect)

        let line1 = Label()
        line1.text = "Dynamic named window generation \(generation)"
        container.addChild(node: line1)

        let line2 = Label()
        line2.text = "This node is destroyed and recreated every 2.5s."
        container.addChild(node: line2)

        window.addChild(node: container)
        root.addChild(node: window)
        showingWindow = true

        sampleLog("Created \(Self.windowNodeName) generation=\(generation) instanceId=\(window.getInstanceId())")
    }

    private func destroyWindowIfPresent() {
        guard
            let root = sceneRoot(),
            let window = root.findChild(pattern: Self.windowNodeName, recursive: true, owned: false) as? SwiftGodot.Window
        else {
            showingWindow = false
            return
        }

        let instanceId = window.getInstanceId()
        window.queueFree()
        showingWindow = false
        sampleLog("Removed \(Self.windowNodeName) instanceId=\(instanceId)")
    }
}

struct ContentView: View {
    init() {
        initHookCb = { level in
            if level == .scene {
                register(type: SpinningCube.self)
                register(type: DynamicNamedWindowSpawner.self)
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

    #if os(macOS)
    @State var app = GodotApp(
        packFile: "",
        godotPackPath: Bundle.module.bundlePath,
        displayDriver: ProcessInfo.processInfo.environment["GODOT_DISPLAY_DRIVER"] ?? "embedded"
    )
    #else
    @State var app = GodotApp(packFile: "main.pck", godotPackPath: Bundle.module.bundlePath)
    #endif

    private func ensureLifecycleSpawner(root: Node) {
        if root.findChild(pattern: DynamicNamedWindowSpawner.spawnerNodeName, recursive: true, owned: false) != nil {
            return
        }
        let spawner = DynamicNamedWindowSpawner()
        spawner.name = StringName(DynamicNamedWindowSpawner.spawnerNodeName)
        root.addChild(node: spawner)
        sampleLog("Installed DynamicNamedWindowSpawner")
    }

    private func installLifecycleSpawnerWhenRootIsReady() {
        app.runOnGodotThread(async: true) {
            guard let root = (Engine.getMainLoop() as? SceneTree)?.root else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    installLifecycleSpawnerWhenRootIsReady()
                }
                return
            }
            ensureLifecycleSpawner(root: root)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            HStack(spacing: 12) {
                GodotAppView(
                    onReady: { handle in
                        sampleLog("GodotAppView onReady root=\(String(describing: handle.getRoot()))")
                        if let root = handle.getRoot() {
                            ensureLifecycleSpawner(root: root)
                        }
                        let message = VariantDictionary()
                        message["type"] = Variant("host_ready")
                        handle.emitMessage(message)
                    },
                    onMessage: { message in
                        sampleLog("GodotAppView onMessage \(message)")
                    }
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Named Window Lifecycle Probe")
                        .font(.headline)
                    Text("Binds to '\(DynamicNamedWindowSpawner.windowNodeName)' while it is repeatedly removed and recreated.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    GodotWindow(node: DynamicNamedWindowSpawner.windowNodeName) { sub in
                        sampleLog("Host bound named window instanceId=\(sub.getInstanceId())")
                    }
                    .background(Color.black.opacity(0.1))
                }
                .frame(minWidth: 420, maxWidth: 420, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .frame(minWidth: 800, minHeight: 600)
        .environment(\.godotApp, app)
        .onAppear {
            app.start()
            installLifecycleSpawnerWhenRootIsReady()
            sampleLog("GodotApp: Started")
        }
    }
}

#Preview {
    ContentView()
}
