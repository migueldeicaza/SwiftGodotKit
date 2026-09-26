import SwiftGodot
import SwiftGodotKit
import SwiftUI

@main
struct AxolotlDemoApp: App {
    @State private var app = GodotApp(packFile: "main.pck")

    var body: some Scene {
        #if os(macOS)
        Window("Axolotl Demo", id: "main") {
            AxolotlGameView(app: app)
        }
        #else
        WindowGroup {
            AxolotlGameView(app: app)
        }
        #endif
    }
}

private struct AxolotlGameView: View {
    let app: GodotApp
    @State private var game = AxolotlGameState()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Score: \(game.score)")
                    .accessibilityAddTraits(.updatesFrequently)
                Spacer()
                Button("Restart game") {
                    game.restart(in: app)
                }
                .disabled(!game.isReady)
            }
            .padding()

            GodotAppView(onReady: { handle in
                game.connect(to: handle)
            })
            .background(Color(red: 0.08, green: 0.18, blue: 0.22))
        }
        .environment(\.godotApp, app)
        .onDisappear {
            game.disconnect(in: app)
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 720)
        #endif
    }
}

@Observable
private final class AxolotlGameState {
    private(set) var score = 0
    private(set) var isReady = false
    @ObservationIgnored private var main: Node?
    @ObservationIgnored private var scoreConnection: Callable?

    func connect(to handle: GodotAppViewHandle) {
        guard main == nil,
              let scene = handle.getRoot()?.findChild(pattern: "Main", recursive: true, owned: false)
        else { return }

        let connection = Callable { [weak self] (value: Int64) in
            DispatchQueue.main.async { [weak self] in
                self?.score = Int(value)
            }
        }
        guard scene.connect(signal: "score_changed", callable: connection) == .ok else { return }
        main = scene
        scoreConnection = connection
        isReady = true
    }

    func restart(in app: GodotApp) {
        app.runOnGodotThread { [weak self] in
            guard let main = self?.main else { return }
            _ = main.call(method: "new_game")
        }
    }

    func disconnect(in app: GodotApp) {
        isReady = false
        guard let main, let scoreConnection else { return }
        app.runOnGodotThread {
            main.disconnect(signal: "score_changed", callable: scoreConnection)
        }
        self.main = nil
        self.scoreConnection = nil
    }
}
