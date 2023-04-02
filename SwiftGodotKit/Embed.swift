//
//  Embed.swift
//  SwiftGodotKit
//
//  Created by Miguel de Icaza on 4/1/23.
//
import Foundation
import SwiftGodot
import libgodot

// Callbacks that the user provides
var loadSceneCb: ((SceneTree) -> ())?
var loadProjectSettingsCb: ((ProjectSettings)->())?

func projectSettingsBind (_ x: UnsafeMutableRawPointer?) {
    if let cb = loadProjectSettingsCb, let ptr = x {
        cb (ProjectSettings(nativeHandle: ptr))
    }
}

func sceneBind (_ startup: UnsafeMutableRawPointer?) {
    if let cb = loadSceneCb, let ptr = startup {
        cb (SceneTree(nativeHandle: ptr))
    }
}

func embeddedExtensionInit (userData: UnsafeMutableRawPointer?, l: GDExtensionInitializationLevel) {
    print ("SwiftEmbed: Register our types here")
}

func embeddedExtensionDeinit (userData: UnsafeMutableRawPointer?, l: GDExtensionInitializationLevel) {
    print ("SwiftEmbed: Unregister here")
}

func initBind ( //() {
    _ ifacePtr: UnsafePointer<GDExtensionInterface>?,
    _ libraryPtr: GDExtensionClassLibraryPtr?,
    _ extensionInit: UnsafeMutablePointer<GDExtensionInitialization>?) -> UInt8 {
        if let iface = ifacePtr {
            setExtensionInterface(to: iface.pointee, library: libraryPtr)
            
            extensionInit?.pointee = GDExtensionInitialization(
                minimum_initialization_level: GDEXTENSION_INITIALIZATION_CORE,
                userdata: nil,
                initialize: embeddedExtensionInit,
                deinitialize: embeddedExtensionDeinit)
            return 1
        }
        
        return 0
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

/// Starts godot with the specified parameters
public func runGodot (args: [String], loadScene: @escaping (SceneTree)->(), loadProjectSettings: @escaping (ProjectSettings)->(), verbose: Bool = false) {
    guard loadSceneCb == nil else {
        print ("runGodot was already invoked")
        return
    }
    loadSceneCb = loadScene
    loadProjectSettingsCb = loadProjectSettings
    
    libgodot_bind(initBind, sceneBind, projectSettingsBind)
    var copy = args
    copy.insert("SwiftGodotKit", at: 0)
    if verbose {
        copy.insert ("--verbose", at: 1)
    }
    withUnsafePtr(strings: copy) { ptr in
        godot_main (Int32 (copy.count), ptr)
    }
    
    // Remember to free the memory when you're done with the pointer
    
}
