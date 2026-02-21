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

public var initHookCb: ((ExtensionInitializationLevel) -> ())?
public var deinitHookCb: ((ExtensionInitializationLevel) -> ())?

let logger = Logger(subsystem: "io.github.migueldeicaza.swiftgodotkit", category: "general")

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
        let argsWithCmd = [ Bundle.main.executablePath ?? "" ] + args
        withUnsafePtr(strings: argsWithCmd, callback: { cstr in
            instance = libgodot.libgodot_create_godot_instance(Int32(argsWithCmd.count), cstr, { godotGetProcAddr, libraryPtr, extensionInit in
                guard let godotGetProcAddr, let libraryPtr, let extensionInit else {
                    return 0
                }

                initializeSwiftModule(
                    unsafeBitCast(godotGetProcAddr, to: OpaquePointer.self),
                    unsafeBitCast(libraryPtr, to: OpaquePointer.self),
                    extensionInit,
                    initHook: { level in
                        initHookCb?(level)
                    },
                    deInitHook: { level in
                        deinitHookCb?(level)
                    },
                    minimumInitializationLevel: .core
                )
                return 1
            })
        })
        if let instance {
            return getOrInitSwiftObject(nativeHandle: instance, ownsRef: false)
        }
        return nil
    }
    
    public static func destroy(instance: GodotInstance) {
        libgodot.libgodot_destroy_godot_instance(UnsafeMutableRawPointer(mutating: instance.handle))
    }
}
