SwiftGodotKit provides a way of embedding Godot into an existing Swift
application and driving Godot from Swift, without having to use an
extension.

This relies currently on the LibGodot patch that is currently pending
approval:

	https://github.com/godotengine/godot/pull/72883

To build the library compile the above fork like this:

```
scons platform=macos target=editor dev_build=yes library_type=shared_library debug_symbols=yes use_asan=true vulkan_sdk_path=~/MoltenVK/
```

I will put together an .xcframework with the binary for folks to try it
out more easily.   In the meantime, you can just take the main branch
of Godot and apply the patch above, create a binary, and then bring
that .xcframework into this directory.