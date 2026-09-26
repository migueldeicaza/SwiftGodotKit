# Axolotl SwiftUI sample

This sample embeds a Godot 4.6 game in a SwiftUI container. It has explicit macOS
14 and iOS 17 targets. Both targets consume the local SwiftGodotKit package and
the binary targets declared by that package.

The container shows the score and a **Restart game** button above the Godot
view. The button calls `new_game()` on the Godot `Main` node. The game emits
`score_changed(value)` when the score resets or increases. SwiftUI connects to
this signal and updates its score label. See `App/AxolotlDemoApp.swift` and
`GodotProject/main.gd` for both sides of this exchange.

The SwiftUI container uses `GodotAppView(onReady:)` to find `Main` and connect a
Swift `Callable` to `score_changed`. Its button calls `new_game` on that node:

```swift
let connection = Callable { (value: Int64) in
    // Update SwiftUI state on the main queue.
}
_ = main.connect(signal: "score_changed", callable: connection)
_ = main.call(method: "new_game")
```

The Godot script declares `signal score_changed(value: int)` and emits it after
each score change. The app keeps the `Callable` and disconnects it when the
SwiftUI view disappears.

The game supports keyboard input on macOS and touch or drag input on iOS. Its
source is in `GodotProject`. The committed `Resources/main.pck` includes the
signal and lets the app build without a Godot editor installation.

To regenerate the pack and Xcode project:

```sh
make
```

The pack script uses `/Applications/Godot-46.app` by default. Set `GODOT_APP`
to use a different Godot 4.6 application bundle.

Build both destinations:

```sh
make build-macos
make build-ios-simulator
```

For a device build, select an Apple development team in Xcode, choose a
physical iPhone or iPad, and run the `AxolotlDemo-iOS` scheme.

See `GodotProject/LICENSE`, `GodotProject/THIRD_PARTY.md`, and
`GodotProject/fonts/LICENSE.txt` for the licenses and attributions.
