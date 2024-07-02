SwiftGodotKit provides a way of embedding Godot into an existing Swift
application and driving Godot from Swift, without having to use an
extension.   This is a companion to [SwiftGodot](https://github.com/migueldeicaza/SwiftGodot) which
provides the API binding to the Godot API.

Take a look at the `TrivialSample` here to see how it works.

You will need Swift 5.9 for this (Xcode 15 release candidate will do).

Reference this Package.swift and then you can write a simple program
like this:

```swift
import Foundation
import SwiftGodot
import SwiftGodotKit

func loadScene (scene: SceneTree) {
    let rootNode = Node3D()
    let camera = Camera3D ()
    camera.current = true
    camera.position = Vector3(x: 0, y: 0, z: 2)
    
    rootNode.addChild(node: camera)
    
    func makeCuteNode (_ pos: Vector3) -> Node {
        let n = SpinningCube()
        n.position = pos
        return n
    }
    rootNode.addChild(node: makeCuteNode(Vector3(x: 1, y: 1, z: 1)))
    rootNode.addChild(node: makeCuteNode(Vector3(x: -1, y: -1, z: -1)))
    rootNode.addChild(node: makeCuteNode(Vector3(x: 0, y: 1, z: 1)))
    scene.root?.addChild(node: rootNode)
}


class SpinningCube: Node3D {
    required init (nativeHandle: UnsafeRawPointer) {
        super.init (nativeHandle: nativeHandle)
    }
    
    required init () {
        super.init ()
        let meshRender = MeshInstance3D()
        meshRender.mesh = BoxMesh()
        addChild(node: meshRender)
    }
    
    override func _input (event: InputEvent) {
        guard event.isPressed () && !event.isEcho () else { return }
        print ("SpinningCube: event: isPressed ")
    }
    
    public override func _process(delta: Double) {
        rotateY(angle: delta)
    }
}

func registerTypes (level: GDExtension.InitializationLevel) {
    switch level {
    case .scene:
        register (type: SpinningCube.self)
    default:
        break
    }
}

runGodot(args: [], initHook: registerTypes, loadScene: loadScene, loadProjectSettings: { settings in })
```

A standalone sample that you can use as a starting point is available here, when used as SwiftPM:

https://github.com/migueldeicaza/SwiftGodotKit/tree/main/StandaloneExample


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
