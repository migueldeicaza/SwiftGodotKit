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
var initHookCb: ((GDExtension.InitializationLevel) -> ())?

let logger = Logger(subsystem: "io.github.migueldeicaza.swiftgodotkit", category: "general")

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

extension GodotInstance {
    public static func create(args: [String]) -> GodotInstance? {
        var instance: UnsafeMutableRawPointer? = nil
        var argsWithCmd = [ Bundle.main.executablePath ?? "" ] + args
        withUnsafePtr(strings: argsWithCmd, callback: { cstr in
            instance = libgodot.libgodot_create_godot_instance/*gCreateGodotInstance*/(Int32(argsWithCmd.count), cstr, { godotGetProcAddr, libraryPtr, extensionInit in
                if let godotGetProcAddr {
                    let bit = unsafeBitCast(godotGetProcAddr, to: OpaquePointer.self)
                    setExtensionInterface(to: bit, library: OpaquePointer (libraryPtr!))
                    extensionInit?.pointee = GDExtensionInitialization(
                        minimum_initialization_level: GDEXTENSION_INITIALIZATION_CORE,
                        userdata: nil,
                        initialize: embeddedExtensionInit,
                        deinitialize: embeddedExtensionDeinit)
                    return 1
                }
                return 0
            })
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
