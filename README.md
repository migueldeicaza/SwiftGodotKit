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

The package manifest consumes published SwiftPM binary targets, but the release
payloads are produced locally from the adjacent `godot` checkout. The helper
script in `scripts/make-libgodot.xcframework` builds and packages the artifacts
that `Package.swift` expects.

Prerequisites:

- Xcode command-line tools.
- `scons` available in `PATH`.
- `gh` authenticated with permission to create releases in `migueldeicaza/godot`
  if you are publishing.
- Adjacent checkouts at `../SwiftGodot` and `../godot`, or pass overrides to
  `make` as shown below.

The script produces this local layout:

```
SwiftGodotKit/build/mac/libgodot.xcframework
SwiftGodotKit/build/mac/libgodot-macos.xcframework.zip
SwiftGodotKit/build/ios/libgodot.xcframework
SwiftGodotKit/build/ios/libgodot-ios.xcframework.zip
```

You can override the default paths and target repository:

```
cd SwiftGodotKit/scripts
make release-payloads SWIFTGODOT=/path/to/SwiftGodot GODOT=/path/to/godot OUTPUT=/tmp/libgodot-build
make publish-release VERSION=v4.6.x GODOT_REPO=owner/repo
```

### Maintainer Release Flow

The canonical release-payload path is:

```
cd SwiftGodotKit/scripts
make release-payloads
```

This builds release Godot slices, packages `build/mac/libgodot.xcframework`
and `build/ios/libgodot.xcframework`, creates SwiftPM payload zips, and prints
the checksums to paste into `Package.swift`.

To publish existing zips to GitHub and update `Package.swift` automatically:

```
cd SwiftGodotKit/scripts
make publish-release VERSION=v4.6.x
```

If you want the Makefile to rebuild the payloads first and then publish them:

```
cd SwiftGodotKit/scripts
make release VERSION=v4.6.x
```

Both publish targets create the GitHub release in `migueldeicaza/godot` using
`gh release create`, upload the macOS and iOS zips, compute the SwiftPM
checksums, and rewrite only the `mac_libgodot` and `ios_libgodot` binary target
URLs/checksums in `Package.swift`. Use a new version tag for every binary
payload; SwiftPM caches binary target URLs aggressively.

After publishing:

1. Review the `Package.swift` diff.
2. Commit the updated binary target URLs/checksums.
3. Tag or release `SwiftGodotKit` so users can depend on the package version
   that references the new libgodot payloads.

The publish target intentionally fails if the GitHub release already exists.
Do not replace zip assets under an existing release tag; SwiftPM clients may
keep stale artifacts or see checksum mismatches.

### Local Packaging Targets

Useful `make` targets:

```
make package          # Package already-built artifacts into local xcframeworks.
make zip              # Package already-built release artifacts and create zips/checksums.
make release-payloads # Build release slices, package xcframeworks, create zips/checksums.
make debug-payloads   # Build debug slices, package xcframeworks, create zips/checksums.
make publish-release VERSION=v4.6.x
make release VERSION=v4.6.x
```

`make release VERSION=v4.6.x` is the full maintainer path: rebuild, zip,
publish to GitHub, and update `Package.swift`.

### Manual Build Commands

If you want to run the steps manually, use the same commands the script runs.
Run these from the adjacent `godot` checkout:

1. Build macOS dylibs (Metal-only, no MoltenVK)
   ```
   scons platform=macos arch=arm64 target=template_release library_type=shared_library vulkan=no metal=yes disable_path_overrides=no
   scons platform=macos arch=x86_64 target=template_release library_type=shared_library vulkan=no metal=yes disable_path_overrides=no
   ```
2. Build iOS static archives (release + simulator slices, Metal-only runtime)
   ```
   scons platform=ios arch=arm64 simulator=no target=template_release vulkan=no metal=yes disable_path_overrides=no
   scons platform=ios arch=arm64 simulator=yes target=template_release vulkan=no metal=yes disable_path_overrides=no
   scons platform=ios arch=x86_64 simulator=yes target=template_release vulkan=no metal=yes disable_path_overrides=no
   ```
3. Package everything:
   ```
   cd SwiftGodotKit/scripts
   make zip
   ```
   After this step `SwiftGodotKit/build/mac/libgodot.xcframework` and
   `SwiftGodotKit/build/ios/libgodot.xcframework` exist and are picked up by
   the manifest automatically. The zip files are created next to each
   xcframework as `libgodot-macos.xcframework.zip` and
   `libgodot-ios.xcframework.zip`.

### How Users Consume A Release

Users do not download the libgodot zips manually. Once `Package.swift` points at
the published binary targets, users add `SwiftGodotKit` through SwiftPM or Xcode:

```swift
.package(url: "https://github.com/migueldeicaza/SwiftGodotKit", exact: "<SwiftGodotKit tag>")
```

and depend on the product:

```swift
.product(name: "SwiftGodotKit", package: "SwiftGodotKit")
```

SwiftPM downloads `libgodot-macos.xcframework.zip` or
`libgodot-ios.xcframework.zip` automatically for the target platform.

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
