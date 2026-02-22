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
based on the new 4.6-based `libgodot` patches that turn Godot into an
embeddable library.

If you are looking for the old version that only ran on macOS, check
out the `legacy` branch.

## Sample Code

### MacOS Sample Code

This module contains a `TrivialSample` example code that shows both
how to embed a Godot-packaged game (PCK files), as well as how to embed
Godot UI elements are created programmatically.  This sample runs on macOS.

### iOS Sample Code

For iOS, you need a proper container; you can look at the peer
[`SwiftGodotKitSamples`](https://github.com/migueldeicaza/SwiftGodotKitSamples) 
project which hosts this library and a sample, and deploys to iOS devices (there 
is no support for the iOS simulator, as Godot does not run on those).

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


# Sausage Making Details 

Check out SwiftGodotKit together with the `godot` engine sources and the Swift
bindings:

```
git clone git@github.com:migueldeicaza/SwiftGodot -b swiftgodotkit # provides the Swift API surface
git clone git@github.com/migueldeicaza/SwiftGodotKit     # this package
git clone git@github.com/migueldeicaza/godot -b swiftgodotkit-4.6 # libgodot-enabled engine sources
```

Important: the `SwiftGodot` and `godot` checkouts must be API-compatible.
For this workspace, use:

- `SwiftGodot` branch: `swiftgodotkit`
- `godot` branch: `swiftgodotkit-4.6`

Using mismatched branches can compile but fail at runtime with null
`gdextension_classdb_get_method_bind` errors.

## Building libgodot locally

The package manifest uses local xcframeworks in `SwiftGodotKit/build/*`.
Build `godot` locally, then package using the helper script in
`scripts/make-libgodot.xcframework`. The script expects the SwiftGodot checkout as well as
the `godot/` directory that ships with this repo and produces the layout that
`Package.swift` looks for:

1. Build macOS dylibs (Metal-only, no MoltenVK)
   ```
   cd godot
   scons platform=macos arch=arm64 target=template_debug library_type=shared_library vulkan=no metal=yes disable_path_overrides=no
   scons platform=macos arch=x86_64 target=template_debug library_type=shared_library vulkan=no metal=yes disable_path_overrides=no
   ```
2. Build iOS static archives (release + simulator slices, Metal-only runtime)
   ```
   cd godot
   scons platform=ios arch=arm64 simulator=no target=template_release vulkan=no metal=yes disable_path_overrides=no
   scons platform=ios arch=arm64 simulator=yes target=template_release vulkan=no metal=yes disable_path_overrides=no
   scons platform=ios arch=x86_64 simulator=yes target=template_release vulkan=no metal=yes disable_path_overrides=no
   ```
3. Package everything:
   ```
   cd SwiftGodotKit/scripts
   make                                  # runs make-libgodot.xcframework ../SwiftGodot ../godot ..
   ```
   After this step `SwiftGodotKit/build/mac/libgodot.xcframework` and
   `SwiftGodotKit/build/ios/libgodot.xcframework` exist and are picked up by
   the manifest automatically.

Note for Godot 4.6 on macOS: template `libgodot` builds usually expose only
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
