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

    var body: some View {
        GodotAppView()
            .background(Color(red: 0.08, green: 0.18, blue: 0.22))
            .environment(\.godotApp, app)
            #if os(macOS)
            .frame(minWidth: 480, minHeight: 720)
            #else
            .ignoresSafeArea()
            #endif
    }
}
