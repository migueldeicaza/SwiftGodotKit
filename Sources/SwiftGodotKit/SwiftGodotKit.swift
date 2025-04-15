//
//  Embed.swift
//  SwiftGodotKit
//
//  Created by Miguel de Icaza on 4/1/23.
//
import Foundation
import SwiftGodot
import libgodot
@_implementationOnly import GDExtension

// Callbacks that the user provides
var loadSceneCb: ((SceneTree) -> ())?
var loadProjectSettingsCb: ((ProjectSettings)->())?
var initHookCb: ((GDExtension.InitializationLevel) -> ())?

func projectSettingsBind (_ x: UnsafeMutableRawPointer?) {
    if let cb = loadProjectSettingsCb, let ptr = x {
        cb (ProjectSettings.createFrom(nativeHandle: ptr))
    }
}

extension GDExtension.InitializationLevel {
    init<T : BinaryInteger>(integerValue: T) {
        self = .init(rawValue: RawValue(integerValue))!
    }
}

func embeddedExtensionInit (userData: UnsafeMutableRawPointer?, l: GDExtensionInitializationLevel) {
    print ("SwiftEmbed: Register our types here, level: \(l)")
    if let cb = initHookCb {
        cb (GDExtension.InitializationLevel(integerValue: l.rawValue))
    }
}

func embeddedExtensionDeinit (userData: UnsafeMutableRawPointer?, l: GDExtensionInitializationLevel) {
    print ("SwiftEmbed: Unregister here")
}

var library: OpaquePointer!
var gfcallbacks = UnsafePointer<GDExtensionInstanceBindingCallbacks> (Wrapped.fcallbacks)
var gucallbacks = UnsafePointer<GDExtensionInstanceBindingCallbacks> (Wrapped.ucallbacks)

// Courtesy of GPT-4
func withUnsafePtr (strings: [String], callback: (UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?)->()) {
    let cStrings: [UnsafeMutablePointer<Int8>?] = strings.map { string in
        // Convert Swift string to a C string (null-terminated)
        return strdup(string)
    }

    // Allocate memory for the array of C string pointers
    let cStringArray = UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>.allocate(capacity: cStrings.count + 1)
    cStringArray.initialize(from: cStrings, count: cStrings.count)

    // Add a null pointer at the end of the array to indicate its end
    cStringArray[cStrings.count] = nil

    callback (cStringArray)
    
    for i in 0..<strings.count {
        free(cStringArray[i])
    }
    cStringArray.deallocate()
}

class KitExtensionInterface: ExtensionInterface {

    /// If your application is crashing due to the Variant leak fixes, please
    /// enable this flag, and provide me with a test case, so I can find that
    /// pesky scenario.
    public let experimentalDisableVariantUnref = false

    private let library: GDExtensionClassLibraryPtr
    private let getProcAddrFun: GDExtensionInterfaceGetProcAddress

    public init(library: GDExtensionClassLibraryPtr, getProcAddr: GDExtensionInterfaceGetProcAddress) {
        self.library = library
        self.getProcAddrFun = getProcAddr
    }

    public func variantShouldDeinit(content: UnsafeRawPointer) -> Bool {
        return !experimentalDisableVariantUnref
    }

    public func objectShouldDeinit(handle: UnsafeRawPointer) -> Bool {
        return true
    }

    public func objectInited(object: Wrapped) {}

    public func objectDeinited(object: Wrapped) {}

    public func variantInited(variant: Variant, content: UnsafeMutableRawPointer) {}

    public func variantDeinited(variant: Variant, content: UnsafeMutableRawPointer) {}

    public func sameDomain(handle: UnsafeRawPointer) -> Bool { true }

    public func getLibrary() -> UnsafeMutableRawPointer {
        return UnsafeMutableRawPointer(mutating: library)
    }

    public func getProcAddr() -> OpaquePointer {
        return unsafeBitCast(getProcAddrFun, to: OpaquePointer.self)
    }

    func getCurrenDomain() -> UInt8 {
        0
    }
}

/// Starts godot with the specified parameters.
///
/// This calls first `initHook()` once Godot has initialized, here you can register
/// types and perform other initialization tasks.   Then `loadProjectSettings` is
/// called with an instance of ProjectSettings, and finally, your `loadScene` is called.
///
/// While this function does return when Godot is shut down, it is not possible to invoke
/// Godot again at this point.
///
/// - Parameters:
///  - args: arguments to pass to Godot
///  - initHook: call to prepare anything before Godot runs, types and others
///  - loadScene: called to load your initial scene
///  - loadProjectSettings: callback to configure your project settings
///  - verbose: whether to show additional logging information.
public func runGodot (args: [String], initHook: @escaping (GDExtension.InitializationLevel) -> (), loadScene: @escaping (SceneTree)->(), loadProjectSettings: @escaping (ProjectSettings)->(), verbose: Bool = false) {
    guard loadSceneCb == nil else {
        print ("runGodot was already invoked, it can currently only be invoked once")
        return
    }
    loadSceneCb = loadScene
    loadProjectSettingsCb = loadProjectSettings
    initHookCb = initHook
    
    libgodot_gdextension_bind { godotGetProcAddr, libraryPtr, extensionInit in
        if let godotGetProcAddr {
            var lib = KitExtensionInterface(library: libraryPtr!, getProcAddr: godotGetProcAddr)
            setExtensionInterface(interface: lib)
            //setExtensionInterface(to: bit, library: OpaquePointer (libraryPtr!))
            library = OpaquePointer (libraryPtr)!
            extensionInit?.pointee = GDExtensionInitialization(
                minimum_initialization_level: GDEXTENSION_INITIALIZATION_CORE,
                userdata: nil,
                initialize: embeddedExtensionInit,
                deinitialize: embeddedExtensionDeinit)
            return 1
        }
        
        return 0
    } _: { startup in
        if let cb = loadSceneCb, let ptr = startup {
            cb (SceneTree.createFrom(nativeHandle: ptr))
        }
    }

    //libgodot_bind(initBind, sceneBind, projectSettingsBind)
    var copy = args
    copy.insert("SwiftGodotKit", at: 0)
    if verbose {
        copy.insert ("--verbose", at: 1)
    }
    withUnsafePtr(strings: copy) { ptr in
        godot_main (Int32 (copy.count), ptr)
    }
}
