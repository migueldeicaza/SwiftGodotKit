//
//  GodotAppWindow.swift
//
//
#if os(macOS)
import SwiftUI
import SwiftGodot

public struct GodotWindow: NSViewRepresentable {
    @SwiftUI.Environment(\.godotApp) var app: GodotApp?
    let callback: ((SwiftGodot.Window)->())?
    var node: String?
    var view = NSGodotWindow()

    public init (callback: ((SwiftGodot.Window)->())?) {
        self.callback = callback
    }
    
    public func makeNSView(context: Context) -> NSGodotWindow {
        view.callback = callback
        view.node = node
        view.app = app
        return view
    }
        
    public func updateNSView(_ nsView: NSGodotWindow, context: Context) {
        nsView.initGodotWindow()
    }
}

public class NSGodotWindow: GodotView {
    private var subwindow: SwiftGodot.Window?
    
    var callback: ((SwiftGodot.Window)->())?
    var node: String?
    var app: GodotApp?
    var inited = false
    
    public override var windowId: Int {
        Int(subwindow?.getWindowId() ?? Int32(DisplayServer.invalidWindowId))
    }
    
    func initGodotWindow() {
        if (!inited) {
            if let instance = app?.instance {
                if !instance.isStarted() {
                    return
                }
                if let node {
                    subwindow = ((Engine.getMainLoop() as? SceneTree)?.root?.findChild(pattern: node) as? SwiftGodot.Window)
                } else {
                    subwindow = Window()
                }
                guard let renderingLayer else {
                    logger.critical("GodotWindow.renderingLayer was not initialized")
                    return
                }
                
                if let subwindow {
                    if let callback {
                        callback(subwindow)
                    }
                    let windowNativeSurface = RenderingNativeSurfaceApple.create(layer: UInt(bitPattern: Unmanaged.passUnretained(renderingLayer).toOpaque()))
                    subwindow.setNativeSurface(windowNativeSurface)
                    if let root = (Engine.getMainLoop() as? SceneTree)?.root {
                        root.addChild(node: subwindow)
                    } else {
                        logger.error("initGodotWindow: could not turn Engine.mainLoop into a sceneTree")
                    }
                    inited = true
                }
            } else if let app {
                app.queueGodotWindow (self)
            }
        }
    }
    
    public override func layout() {
        renderingLayer?.frame = self.bounds
        if inited {
            if embedded == nil {
                embedded = DisplayServerEmbedded(nativeHandle: DisplayServer.shared.handle!)
            }
            resizeWindow ()
        }
        super.layout()
    }
    
    public override func removeFromSuperview() {
        subwindow?.getParent()?.removeChild(node: subwindow)
        super.removeFromSuperview()
    }
}
#endif
