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


## Godot 4.7 payloads

This branch uses the
[`v4.7.3-rc-swiftgodotkit.1`](https://github.com/migueldeicaza/godot/releases/tag/v4.7.3-rc-swiftgodotkit.1)
macOS and iOS payloads. `Package.swift` pins the matching SwiftGodot commit.
SwiftPM downloads the binaries when it builds the package.

SwiftGodotKit pins SwiftGodot's `unify/main` commit for its Godot 4.7 API.
SwiftGodot's `main` currently contains the Godot 4.6 API. Kit calls its
custom surface and display methods through cached GDExtension method binds,
so those methods do not need generated SwiftGodot classes. The pin can move
to `main` after its generated API moves to Godot 4.7.

### Rebuild the payloads locally

Keep these three checkouts next to each other:

- `godot`: branch `swiftgodotkit-4.7`, based on `upstream/4.7`.
- `SwiftGodot`: the pinned `unify/main` commit in `Package.swift`.
- `SwiftGodotKit`: branch `swiftgodotkit-4.7`.

To reproduce the payloads, build the engine archives and XCFrameworks:

```sh
cd SwiftGodotKit/scripts
make release-payloads
```

This builds macOS arm64 and x86_64 dylibs, and iOS device and simulator
archives. It creates `build/mac/libgodot.xcframework` and
`build/ios/libgodot.xcframework`, with zip files and checksums next to them.
The process can take several minutes. If the five engine slices already exist
for the current 4.7 commit, run `make package` to package them again.
To test a new local engine build, change the two binary targets in
`Package.swift` from `url` and `checksum` to these local XCFramework paths.

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

For the next payload release, push the matching Godot commit.
Then run `make publish-release VERSION=<new tag>` from `scripts/`. This uploads
the two zip files to a Godot release and updates the binary URLs and checksums
in `Package.swift`. Set `RELEASE_PRERELEASE=1` for a prerelease. Update the
SwiftGodot revision if its bindings changed. Use a new tag for each payload
because SwiftPM caches the URL.

### Use the 4.7 branch

Add the current 4.7 branch through SwiftPM or Xcode:

```swift
.package(url: "https://github.com/migueldeicaza/SwiftGodotKit", branch: "swiftgodotkit-4.7")
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
