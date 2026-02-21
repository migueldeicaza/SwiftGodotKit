
import Foundation
import SwiftGodot
import SwiftGodotKit
import SwiftUI

private func sampleLog(_ message: String) {
    if let data = ("[TrivialSample] \(message)\n").data(using: .utf8) {
        FileHandle.standardError.write(data)
    }
}

private let runtimeEventTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    return formatter
}()

private struct RuntimeEventEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let category: String
    let message: String
}

private func runtimeEventCategory(_ event: GodotAppEvent) -> String {
    switch event {
    case .startupFailure(let failure):
        return "startupFailure.\(failure.reason.rawValue)"
    case .warning(let warning):
        return "warning.\(warning.code.rawValue)"
    case .bridge(let bridge):
        return "bridge.\(bridge.state.rawValue)"
    case .windowBinding(let binding):
        return "windowBinding.\(binding.state.rawValue)"
    case .lifecycle(let lifecycle):
        return "lifecycle.\(lifecycle.label)"
    }
}

private func describeRuntimeEvent(_ event: GodotAppEvent) -> String {
    switch event {
    case .startupFailure(let failure):
        return "GodotAppEvent startupFailure reason=\(failure.reason.rawValue) sourcePath=\(failure.sourcePath) scene=\(failure.scene ?? "<nil>")"
    case .warning(let warning):
        return "GodotAppEvent warning code=\(warning.code.rawValue) detail=\(warning.detail)"
    case .bridge(let bridge):
        return "GodotAppEvent bridge state=\(bridge.state.rawValue)"
    case .windowBinding(let binding):
        return "GodotAppEvent windowBinding state=\(binding.state.rawValue) platform=\(binding.platform) node=\(binding.nodeName ?? "<nil>") instanceId=\(binding.instanceId.map(String.init) ?? "<nil>") ownsWindow=\(binding.ownsWindow)"
    case .lifecycle(let lifecycle):
        return "GodotAppEvent lifecycle label=\(lifecycle.label) notification=\(lifecycle.notification)"
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
    @State private var runtimeEventHandlerId: UUID?
    @State private var runtimeEventCounts: [String: Int] = [:]
    @State private var runtimeEvents: [RuntimeEventEntry] = []

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

    private var sortedRuntimeEventCounts: [(key: String, value: Int)] {
        runtimeEventCounts.sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key < rhs.key
            }
            return lhs.value > rhs.value
        }
    }

    private func recordRuntimeEvent(_ event: GodotAppEvent) {
        let message = describeRuntimeEvent(event)
        sampleLog(message)

        let category = runtimeEventCategory(event)
        runtimeEventCounts[category, default: 0] += 1
        runtimeEvents.append(
            RuntimeEventEntry(
                timestamp: Date(),
                category: category,
                message: message
            )
        )

        let maxEventCount = 150
        if runtimeEvents.count > maxEventCount {
            runtimeEvents.removeFirst(runtimeEvents.count - maxEventCount)
        }
    }

    private var diagnosticsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Runtime Diagnostics")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    runtimeEventCounts.removeAll()
                    runtimeEvents.removeAll()
                }
                .buttonStyle(.bordered)
                .disabled(runtimeEvents.isEmpty)
            }

            if sortedRuntimeEventCounts.isEmpty {
                Text("Waiting for runtime events...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sortedRuntimeEventCounts, id: \.key) { item in
                            Text("\(item.key): \(item.value)")
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(runtimeEvents.suffix(30).reversed())) { event in
                        Text("\(runtimeEventTimeFormatter.string(from: event.timestamp)) [\(event.category)] \(event.message)")
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxHeight: 170)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
            diagnosticsPanel
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(minWidth: 800, minHeight: 600)
        .environment(\.godotApp, app)
        .onAppear {
            if runtimeEventHandlerId == nil {
                runtimeEventHandlerId = app.registerEventHandler { event in
                    if Thread.isMainThread {
                        recordRuntimeEvent(event)
                    } else {
                        DispatchQueue.main.async {
                            recordRuntimeEvent(event)
                        }
                    }
                }
            }
            app.start()
            installLifecycleSpawnerWhenRootIsReady()
            sampleLog("GodotApp: Started")
        }
        .onDisappear {
            app.unregisterEventHandler(runtimeEventHandlerId)
            runtimeEventHandlerId = nil
        }
    }
}

#Preview {
    ContentView()
}
