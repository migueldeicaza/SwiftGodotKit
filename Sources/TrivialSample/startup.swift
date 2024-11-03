//
//  main.swift
//
// Very trivial example of using SwiftGodotKit
//
//  Created by Miguel de Icaza on 4/1/23.
//
import SwiftUI
import AppKit
import SwiftGodot

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

@main
struct testAppkitUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

