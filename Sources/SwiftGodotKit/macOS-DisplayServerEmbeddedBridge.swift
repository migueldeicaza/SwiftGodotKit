#if os(macOS)
import SwiftGodot
@_spi(SwiftGodotRuntimePrivate) import SwiftGodotRuntime

enum DisplayServerMacOSEmbeddedBridge {
    private static var className = StringName("DisplayServerMacOSEmbedded")

    private static let setNativeSurfaceMethod = methodBind("set_native_surface", hash: 2894024005)
    private static let resizeWindowMethod = methodBind("resize_window", hash: 3200960707)

    private static func methodBind(_ name: StaticString, hash: Int64) -> UnsafeRawPointer? {
        var methodName = FastStringName(name)
        return withUnsafePointer(to: &className.content) { classPtr in
            withUnsafePointer(to: &methodName.content) { methodPtr in
                gi.classdb_get_method_bind(classPtr, methodPtr, hash)
            }
        }
    }

    static func current() -> DisplayServer? {
        let server = DisplayServer.shared
        guard server.getClass() == "DisplayServerMacOSEmbedded" else { return nil }
        return server
    }

    @discardableResult
    static func setNativeSurface(_ surface: RefCounted?) -> Bool {
        guard let method = setNativeSurfaceMethod else { return false }
        withUnsafePointer(to: surface?.handle) { surfacePtr in
            let args: [UnsafeRawPointer?] = [UnsafeRawPointer(surfacePtr)]
            args.withUnsafeBufferPointer { buffer in
                gi.object_method_bind_ptrcall(method, nil, buffer.baseAddress, nil)
            }
        }
        return true
    }

    @discardableResult
    static func resizeWindow(_ server: DisplayServer, size: Vector2i, id: Int32) -> Bool {
        guard let method = resizeWindowMethod else { return false }
        let windowID = Int64(id)
        withUnsafePointer(to: size) { sizePtr in
            withUnsafePointer(to: windowID) { idPtr in
                let args: [UnsafeRawPointer?] = [UnsafeRawPointer(sizePtr), UnsafeRawPointer(idPtr)]
                args.withUnsafeBufferPointer { buffer in
                    gi.object_method_bind_ptrcall(method, server.handle, buffer.baseAddress, nil)
                }
            }
        }
        return true
    }
}
#endif
