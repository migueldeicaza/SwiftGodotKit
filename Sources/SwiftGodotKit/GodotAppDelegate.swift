//
//  GodotAppDelegate.swift
//
//

#if os(macOS)

import Foundation
import AppKit

import SwiftGodot

open class GodotAppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidBecomeActive(_ aNotification: Notification) {
        Engine.getMainLoop()?.notification(what: Int32(MainLoop.notificationApplicationFocusIn))
    }
    
    public func applicationDidResignActive(_ aNotification: Notification) {
        Engine.getMainLoop()?.notification(what: Int32(MainLoop.notificationApplicationFocusOut))
    }
}

#endif
