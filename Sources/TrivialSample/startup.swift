//
//  main.swift
//
// Very trivial example of using SwiftGodotKit
//
//  Created by Miguel de Icaza on 4/1/23.
//
import SwiftUI
import SwiftGodot

#if os(macOS)
import AppKit
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidResignActive(_ notification: Notification) {
        Engine.getMainLoop()?.notification(what: Int32(MainLoop.notificationApplicationFocusOut))
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        Engine.getMainLoop()?.notification(what: Int32(MainLoop.notificationApplicationFocusIn))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print ("Lauching")
    }
}
#endif

@main
struct testAppkitUIApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

