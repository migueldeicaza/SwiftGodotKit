import SwiftGodotKit
import SwiftUI

struct ContentView: View {
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
