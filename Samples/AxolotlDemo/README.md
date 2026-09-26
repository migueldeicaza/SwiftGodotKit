# Axolotl SwiftUI sample

This sample embeds a Godot 4.6 game in one SwiftUI view. It has explicit macOS
14 and iOS 17 targets. Both targets consume the local SwiftGodotKit package and
the binary targets declared by that package.

The game supports keyboard input on macOS and touch or drag input on iOS. Its
source is in `GodotProject`. The committed `Resources/main.pck` lets the app
build without a Godot editor installation.

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
