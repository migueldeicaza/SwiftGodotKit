//
//  Embed.swift
//  SwiftGodotKit
//
//  Created by Miguel de Icaza on 4/1/23.
//
import Foundation
import SwiftGodot
import libgodot
import QuartzCore
@_implementationOnly import GDExtension
import os

public var initHookCb: ((GDExtension.InitializationLevel) -> ())?
public var deinitHookCb: ((GDExtension.InitializationLevel) -> ())?

let logger = Logger(subsystem: "io.github.migueldeicaza.swiftgodotkit", category: "general")

extension GDExtension.InitializationLevel {
    init<T : BinaryInteger>(integerValue: T) {
        self = .init(rawValue: RawValue(integerValue))!
    }
}

func embeddedExtensionInit (userData: UnsafeMutableRawPointer?, l: GDExtensionInitializationLevel) {
    let level = GDExtension.InitializationLevel(integerValue: l.rawValue)
    print ("SwiftEmbed: Register our types here, level: \(level)")
    if let cb = initHookCb {
        cb (GDExtension.InitializationLevel(integerValue: l.rawValue))
    }
}

func embeddedExtensionDeinit (userData: UnsafeMutableRawPointer?, l: GDExtensionInitializationLevel) {
    if let cb = deinitHookCb {
        cb (GDExtension.InitializationLevel(integerValue: l.rawValue))
    }
}

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

//                    let bit = unsafeBitCast(godotGetProcAddr, to: OpaquePointer.self)
// setExtensionInterface(to: bit, library: OpaquePointer (libraryPtr!))

class EmbeddedExtensionInterface: ExtensionInterface {
    func variantShouldDeinit(content: UnsafeRawPointer) -> Bool {
        return true
    }
    
    func objectShouldDeinit(handle: UnsafeRawPointer) -> Bool {
        return true
    }
    
    func objectInited(object: SwiftGodot.Wrapped) {
    }
    
    func objectDeinited(object: SwiftGodot.Wrapped) {
    }
    
    func variantInited(variant: SwiftGodot.Variant, content: UnsafeMutableRawPointer) {
    }
    
    func variantDeinited(variant: SwiftGodot.Variant, content: UnsafeMutableRawPointer) {
    }
    
    func getLibrary() -> UnsafeMutableRawPointer {
        return library
    }
    
    func getProcAddr() -> OpaquePointer {
        return unsafeBitCast(getProcAddrFun, to: OpaquePointer.self)
    }
    
    func sameDomain(handle: UnsafeRawPointer) -> Bool {
        true
    }
    
    func getCurrenDomain() -> UInt8 {
        0
    }

    var library: UnsafeMutableRawPointer
    var getProcAddrFun: GDExtensionInterfaceGetProcAddress

    init(library: UnsafeMutableRawPointer, getProcAddrFun: GDExtensionInterfaceGetProcAddress) {
        self.library = library
        self.getProcAddrFun = getProcAddrFun
    }
}

extension GodotInstance {
    public static func create(args: [String]) -> GodotInstance? {
        var instance: UnsafeMutableRawPointer? = nil
        let argsWithCmd = [ Bundle.main.executablePath ?? "" ] + args
        withUnsafePtr(strings: argsWithCmd, callback: { cstr in
            instance = libgodot.libgodot_create_godot_instance/*gCreateGodotInstance*/(Int32(argsWithCmd.count), cstr, { godotGetProcAddr, libraryPtr, extensionInit in
                if let godotGetProcAddr {
                    let ext = EmbeddedExtensionInterface(library: UnsafeMutableRawPointer(libraryPtr!), getProcAddrFun: godotGetProcAddr)
                    setExtensionInterface(interface: ext)
                    extensionInit?.pointee = GDExtensionInitialization(
                        minimum_initialization_level: GDEXTENSION_INITIALIZATION_CORE,
                        userdata: nil,
                        initialize: embeddedExtensionInit,
                        deinitialize: embeddedExtensionDeinit)
                    return 1
                }
                return 0
            }, nil, nil, nil, nil)
        })
        if instance != nil {
            return GodotInstance(nativeHandle: instance!)
        }
        return nil
    }
    
    public static func destroy(instance: GodotInstance) {
        libgodot.libgodot_destroy_godot_instance(UnsafeMutableRawPointer(mutating: instance.handle))
    }
}
