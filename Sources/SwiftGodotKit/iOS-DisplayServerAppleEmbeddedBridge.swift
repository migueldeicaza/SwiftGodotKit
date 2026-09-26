//
//  iOS-DisplayServerAppleEmbeddedBridge.swift
//

#if os(iOS)
import SwiftGodot
@_spi(SwiftGodotRuntimePrivate) import SwiftGodotRuntime

enum DisplayServerAppleEmbeddedBridge {
    typealias Handle = GodotNativeObjectPointer

    private static var className = StringName("DisplayServerAppleEmbedded")

    private static let methodSetNativeSurface = methodBind("set_native_surface", hash: 2894024005)
    private static let methodGetSingleton = methodBind("get_singleton", hash: 3060309051)
    private static let methodResizeWindow = methodBind("resize_window", hash: 3200960707)
    // These hashes include the default MAIN_WINDOW_ID argument from the iOS bindings.
    private static let methodTouchPress = methodBind("touch_press", hash: 3390648327)
    private static let methodTouchDrag = methodBind("touch_drag", hash: 1449279906)
    private static let methodTouchesCanceled = methodBind("touches_canceled", hash: 2230941749)

    private static func methodBind(_ method: StaticString, hash: Int64) -> UnsafeRawPointer? {
        var methodName = FastStringName(method)
        return withUnsafePointer(to: &className.content) { classPtr in
            withUnsafePointer(to: &methodName.content) { methodPtr in
                gi.classdb_get_method_bind(classPtr, methodPtr, hash)
            }
        }
    }

    @discardableResult
    static func setNativeSurface(_ nativeSurface: RenderingNativeSurface?) -> Bool {
        guard let method = methodSetNativeSurface else { return false }
        withUnsafePointer(to: nativeSurface?.handle) { pArg0 in
            let args: [UnsafeRawPointer?] = [UnsafeRawPointer(pArg0)]
            args.withUnsafeBufferPointer { pArgs in
                gi.object_method_bind_ptrcall(method, nil, pArgs.baseAddress, nil)
            }
        }
        return true
    }

    static func getSingleton() -> Handle? {
        guard let method = methodGetSingleton else { return nil }
        var result = GodotNativeObjectPointer(bitPattern: 0)
        gi.object_method_bind_ptrcall(method, nil, nil, &result)
        return result
    }

    @discardableResult
    static func resizeWindow(_ displayServer: Handle?, size: Vector2i, id: Int32) -> Bool {
        guard let method = methodResizeWindow, let displayServer else { return false }
        withUnsafePointer(to: size) { pArg0 in
            withUnsafePointer(to: id) { pArg1 in
                let args: [UnsafeRawPointer?] = [UnsafeRawPointer(pArg0), UnsafeRawPointer(pArg1)]
                args.withUnsafeBufferPointer { pArgs in
                    gi.object_method_bind_ptrcall(method, displayServer, pArgs.baseAddress, nil)
                }
            }
        }
        return true
    }

    @discardableResult
    static func touchPress(
        _ displayServer: Handle?,
        idx: Int32,
        x: Int32,
        y: Int32,
        pressed: Bool,
        doubleClick: Bool,
        window: Int32
    ) -> Bool {
        guard let method = methodTouchPress, let displayServer else { return false }
        withUnsafePointer(to: idx) { pArg0 in
            withUnsafePointer(to: x) { pArg1 in
                withUnsafePointer(to: y) { pArg2 in
                    withUnsafePointer(to: pressed) { pArg3 in
                        withUnsafePointer(to: doubleClick) { pArg4 in
                            withUnsafePointer(to: window) { pArg5 in
                                let args: [UnsafeRawPointer?] = [
                                    UnsafeRawPointer(pArg0),
                                    UnsafeRawPointer(pArg1),
                                    UnsafeRawPointer(pArg2),
                                    UnsafeRawPointer(pArg3),
                                    UnsafeRawPointer(pArg4),
                                    UnsafeRawPointer(pArg5),
                                ]
                                args.withUnsafeBufferPointer { pArgs in
                                    gi.object_method_bind_ptrcall(method, displayServer, pArgs.baseAddress, nil)
                                }
                            }
                        }
                    }
                }
            }
        }
        return true
    }

    @discardableResult
    static func touchDrag(
        _ displayServer: Handle?,
        idx: Int32,
        prevX: Int32,
        prevY: Int32,
        x: Int32,
        y: Int32,
        pressure: Double,
        tilt: Vector2,
        window: Int32
    ) -> Bool {
        guard let method = methodTouchDrag, let displayServer else { return false }
        withUnsafePointer(to: idx) { pArg0 in
            withUnsafePointer(to: prevX) { pArg1 in
                withUnsafePointer(to: prevY) { pArg2 in
                    withUnsafePointer(to: x) { pArg3 in
                        withUnsafePointer(to: y) { pArg4 in
                            withUnsafePointer(to: pressure) { pArg5 in
                                withUnsafePointer(to: tilt) { pArg6 in
                                    withUnsafePointer(to: window) { pArg7 in
                                        let args: [UnsafeRawPointer?] = [
                                            UnsafeRawPointer(pArg0),
                                            UnsafeRawPointer(pArg1),
                                            UnsafeRawPointer(pArg2),
                                            UnsafeRawPointer(pArg3),
                                            UnsafeRawPointer(pArg4),
                                            UnsafeRawPointer(pArg5),
                                            UnsafeRawPointer(pArg6),
                                            UnsafeRawPointer(pArg7),
                                        ]
                                        args.withUnsafeBufferPointer { pArgs in
                                            gi.object_method_bind_ptrcall(method, displayServer, pArgs.baseAddress, nil)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return true
    }

    @discardableResult
    static func touchesCanceled(_ displayServer: Handle?, idx: Int32, window: Int32) -> Bool {
        guard let method = methodTouchesCanceled, let displayServer else { return false }
        withUnsafePointer(to: idx) { pArg0 in
            withUnsafePointer(to: window) { pArg1 in
                let args: [UnsafeRawPointer?] = [UnsafeRawPointer(pArg0), UnsafeRawPointer(pArg1)]
                args.withUnsafeBufferPointer { pArgs in
                    gi.object_method_bind_ptrcall(method, displayServer, pArgs.baseAddress, nil)
                }
            }
        }
        return true
    }
}
#endif
