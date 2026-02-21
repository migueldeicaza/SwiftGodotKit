//
//  GodotAppDelegate.swift
//
//

#if os(macOS)

import Foundation
import AppKit

import SwiftGodot

open class GodotAppDelegate: NSObject, NSApplicationDelegate {
    weak var app: GodotApp?

    public func applicationDidBecomeActive(_ aNotification: Notification) {
        app?.applicationDidBecomeActive()
    }
    
    public func applicationDidResignActive(_ aNotification: Notification) {
        app?.applicationDidResignActive()
    }
}

#endif
