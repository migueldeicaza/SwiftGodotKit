SwiftGodotKit provides a way of embedding Godot into an existing Swift
application and driving Godot from Swift, without having to use an
extension.   This is a companion to [SwiftGodot](https://github.com/migueldeicaza/SwiftGodot) which
provides the API binding to the Godot API.

# New SwiftGodotKit

This branch contains the new embeddable system that is better suited
to be embedded into an existing iOS app (Mac support is not ready),
and allows either a full game to be displayed, or indidivual parts in
an app.

## Using this

This is a work-in-progress and requires some assembly until I have
time to package this properly.

This branch requires a peer "SwiftGodot" for branch "libgodot-4.3" and
it also requires the scripts/ios/libgodot.xcframework that is built from
github.com/migeran/libgodot_project branch libgodot_migeran_next_44 using `build_libgodot.sh`

## Sample

A simple SwiftUI API is provided.

In the example below, in an existing iOS project type using SwiftUI,
add a Godot PCK file to your project, and then call it like this:

```
import SwiftUI
import SwiftGodot
import SwiftGodotKit

struct ContentView: View {
    @State var app = GodotApp(packFile: "game.pck")

    var body: some View {
        VStack {
            Text("Game is below:")
            GodotAppView(app: app)
                .padding()
        }
    }
}
```


# Sausage Making Details 

If you want to compile your own version of `libgodot.framework`, follow 
these instructions

Check out SwiftGodot and SwiftGodotKit as peers as well as a version
of Godot suitable to be used as a library:

```
git clone git@github.com:migueldeicaza/SwiftGodot
git clone git@github.com:migueldeicaza/SwiftGodotKit
git clone git@github.com:migueldeicaza/libgodot
```

Compile libgodot, this sample shows how I do this myself, but
you could have different versions

```
cd libgodot
scons target=template_debug dev_build=yes library_type=shared_library debug_symbols=yes 
```

The above will produce the binary that you want, then create an
xcframework out of it, using the script in SwiftGodot (a peer to this
repository):

```
cd ../SwiftGodot/scripts
sh -x make-libgodot.xcframework ../../SwiftGodot ../../libgodot /tmp/
```

Then you can reference that version of the libgodot.xcframework

## Details

This relies currently on the LibGodot patch that is currently pending
approval:

    https://github.com/godotengine/godot/pull/72883

For your convenience, I have packaged the embeddable Godot for Mac as an `xcframework`
so merely taking a dependency on this package should get everything that you need
