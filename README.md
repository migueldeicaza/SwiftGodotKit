SwiftGodotKit provides a way of embedding Godot into an existing Swift
application and driving Godot from Swift, without having to use an
extension.   This is a companion to [SwiftGodot](https://github.com/migueldeicaza/SwiftGodot), which
provides the API binding to the Godot API.  The structure mirrors the
`react-native-godot` package that lives next to this directory – both rely
on the new `libgodot` entry points that are part of the `godot/` checkout
that ships with this workspace.

# New SwiftGodotKit

This branch contains the new embeddable system that is better suited
to be embedded into an existing iOS and Mac app, and allows either a
full game to be displayed, or individual parts in an app.  This is
based on the Godot 4.7 `libgodot` patches that turn Godot into an
embeddable library.

If you are looking for the old version that only ran on macOS, check
out the `legacy` branch.

## Sample Code

### macOS Sample Code

This module contains a `TrivialSample` example code that shows both
how to embed a Godot-packaged game (PCK files), as well as how to embed
Godot UI elements are created programmatically.  This sample runs on macOS.

### iOS Sample Code

[`Samples/AxolotlDemo`](Samples/AxolotlDemo/README.md) is a SwiftUI container for
macOS and iOS. It shows both directions of communication: a SwiftUI button
calls Godot's `new_game()` method, and a Godot `score_changed` signal updates a
SwiftUI score label. The sample includes a `main.pck` game pack and supports
iOS devices and the iOS simulator. See the sample README for build and run
instructions.

## Using this

Just reference this module from your Package.swift file or from Xcode.

## Sample

A simple SwiftUI API is provided.

In the example below, in an existing iOS project type using SwiftUI,
add a Godot PCK file to your project, and then call it like this:

```swift
import SwiftUI
import SwiftGodot
import SwiftGodotKit

struct ContentView: View {
    @State var app = GodotApp(packFile: "game.pck")

    var body: some View {
        VStack {
            Text("Game is below:")
            GodotAppView()
                .padding()
        }
	.environment(\.godotApp, app)
    }
}
```

There can only be one GodotApp in your application, but you can reference different scenes from it.

# Discussions

You can join our [Discussions on GitHub](https://github.com/migueldeicaza/SwiftGodot/discussions) or the #swiftgodotkit
channel on the [Swift on Godot Slack server](https://join.slack.com/t/swiftongodot/shared_invite/zt-2aqygohvb-stSRGEAN~c3awuMwtaqCAA).


## Local Godot 4.7 build

Keep these three checkouts next to each other:

- `godot`: branch `swiftgodotkit-4.7`, based on `upstream/4.7`.
- `SwiftGodot`: branch `swiftgodotkit-4.7`, based on `origin/unify/main`.
- `SwiftGodotKit`: branch `swiftgodotkit-4.7`.

The package uses the adjacent SwiftGodot checkout and local 4.7 XCFrameworks.
Build the engine payloads before you build an app:

```sh
cd SwiftGodotKit/scripts
make release-payloads
```

This builds macOS arm64 and x86_64 dylibs, and iOS device and simulator
archives. It creates `build/mac/libgodot.xcframework` and
`build/ios/libgodot.xcframework`, with zip files and checksums next to them.
The process can take several minutes. If the five engine slices already exist
for the current 4.7 commit, run `make package` to package them again.

You need Xcode command-line tools and `scons` in `PATH`. The default paths use
the adjacent checkouts. You can set `SWIFTGODOT`, `GODOT`, and `OUTPUT` when you
run `make`.

To build the SwiftUI sample, run:

```sh
cd SwiftGodotKit/Samples/AxolotlDemo
make
make build-macos
make build-ios-simulator
```

The sample pack script uses `/Applications/Godot-47.app`. Set `GODOT_APP` if
you keep the Godot 4.7 editor at a different path.

The local paths in `Package.swift` are for this workspace. Before a public
release, push the matching Godot and SwiftGodot commits. Then run
`make publish-release VERSION=<new tag>` from `scripts/`. This uploads the two
zip files to the Godot release and replaces the binary target paths in
`Package.swift` with release URLs and checksums. Pin the SwiftGodot commit
that contains the matching custom 4.7 bindings before you release
SwiftGodotKit. Use a new tag for each payload because SwiftPM caches the URL.

### How Users Consume A Release

After the 4.7 payloads are published and `Package.swift` points to them,
users can add `SwiftGodotKit` through SwiftPM or Xcode:

```swift
.package(url: "https://github.com/migueldeicaza/SwiftGodotKit", exact: "<SwiftGodotKit tag>")
```

and depend on the product:

```swift
.product(name: "SwiftGodotKit", package: "SwiftGodotKit")
```

SwiftPM downloads `libgodot-macos.xcframework.zip` or
`libgodot-ios.xcframework.zip` automatically for the target platform.

Note for Godot 4.7 on macOS: template `libgodot` builds usually expose only
`macos`/`headless` display drivers. `TrivialSample` therefore defaults to
`macos` on macOS. If you want true embedded rendering (`--display-driver embedded`)
you need a `libgodot` build that registers the embedded display driver.

### Legacy notes

For older setups, you may still find notes referring to `libgodot_44_stable`.
Compile libgodot, this sample shows how I do this myself, but
you can pass the flags that make sense for your scenarios:


```
cd libgodot
scons target=template_debug dev_build=yes library_type=shared_library debug_symbols=yes 
```

The above will produce the binary that you want, then create an
xcframework out of it, using the script in this directory or in the
SwiftGodot scripts folder.
