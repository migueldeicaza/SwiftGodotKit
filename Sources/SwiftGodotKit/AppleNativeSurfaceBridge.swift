// Calls the engine classes that are specific to SwiftGodotKit. SwiftGodot's
// generated bindings only need the standard Godot 4.7 API.

#if os(macOS) || os(iOS)
import SwiftGodot
@_spi(SwiftGodotRuntimePrivate) import SwiftGodotRuntime

enum AppleNativeSurfaceBridge {
    private static var surfaceClassName = StringName("RenderingNativeSurfaceApple")
    private static var windowClassName = StringName("Window")

    private static let createMethod = methodBind(
        className: &surfaceClassName, method: "create", hash: 4233771684
    )
    private static let setWindowSurfaceMethod = methodBind(
        className: &windowClassName, method: "set_native_surface", hash: 2894024005
    )

    private static func methodBind(
        className: inout StringName, method: StaticString, hash: Int64
    ) -> UnsafeRawPointer? {
        var methodName = FastStringName(method)
        return withUnsafePointer(to: &className.content) { classPtr in
            withUnsafePointer(to: &methodName.content) { methodPtr in
                gi.classdb_get_method_bind(classPtr, methodPtr, hash)
            }
        }
    }

    static func create(layer: UInt) -> RefCounted? {
        guard let method = createMethod else { return nil }
        var result = GodotNativeObjectPointer(bitPattern: 0)
        withUnsafePointer(to: layer) { layerPtr in
            let args: [UnsafeRawPointer?] = [UnsafeRawPointer(layerPtr)]
            args.withUnsafeBufferPointer { buffer in
                gi.object_method_bind_ptrcall(method, nil, buffer.baseAddress, &result)
            }
        }
        guard let result else { return nil }
        // The runtime class is a RefCounted subclass that SwiftGodot does not generate.
        return getOrInitSwiftObject(nativeHandle: result, ownership: .godotApiReturn)
    }

    static func bindWindow(layer: UInt, to window: SwiftGodot.Window) -> Bool {
        guard let surface = create(layer: layer) else { return false }
        guard let method = setWindowSurfaceMethod else { return false }
        withUnsafePointer(to: surface.handle) { surfacePtr in
            let args: [UnsafeRawPointer?] = [UnsafeRawPointer(surfacePtr)]
            args.withUnsafeBufferPointer { buffer in
                gi.object_method_bind_ptrcall(method, window.handle, buffer.baseAddress, nil)
            }
        }
        return true
    }
}
#endif
