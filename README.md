SwiftGodotKit provides a way of embedding Godot into an existing Swift
application and driving Godot from Swift, without having to use an
extension.

This relies currently on the LibGodot patch that is currently pending
approval:

	https://github.com/godotengine/godot/pull/72883

# Building

Check out SwiftGodot and SwiftGodotKit as peers as well as a version
of Godot suitable to be used as a library:

```
git clone git@github.com:migueldeicaza/SwiftGodot
git clone git@github.com:migueldeicaza/SwiftGodotKit
git clone git@github.com:migueldeicaza/libgodot
```

Compile libgodot:

```
cd libgodot
scons target=template_debug dev_build=yes library_type=shared_library debug_symbols=yes 
```

The above will produce the binary that you want, then create an
xcframework out of it, using the script in SwiftGodot (a peer to this
repository):

```
cd ../SwiftGodot/scripts
bash make-libgodot.xcframework ../../libgodot ..
```

Then you can open the SwiftGodotKit solution in this directory which
references the `libgodot.xcframework`.

