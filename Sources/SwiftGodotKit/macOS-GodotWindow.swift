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
    let node: String?
    var view = NSGodotWindow()

    public init(node: String? = nil, callback: ((SwiftGodot.Window)->())?) {
        self.callback = callback
        self.node = node
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
    private var ownsSubwindow = false
    
    var callback: ((SwiftGodot.Window)->())?
    var node: String?
    var app: GodotApp?
    var inited = false
    
    public override var windowId: Int {
        Int(subwindow?.getWindowId() ?? Int32(DisplayServer.invalidWindowId))
    }
    
    func initGodotWindow() {
        guard app?.displayDriver == "embedded" else {
            return
        }
        if (!inited) {
            if let instance = app?.instance {
                if !instance.isStarted() {
                    return
                }
                if let node {
                    guard let existingWindow = (Engine.getMainLoop() as? SceneTree)?.root?.findChild(pattern: node) as? SwiftGodot.Window else {
                        logger.error("initGodotWindow: missing window named \(node, privacy: .public)")
                        return
                    }
                    subwindow = existingWindow
                    ownsSubwindow = false
                } else {
                    subwindow = Window()
                    ownsSubwindow = true
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
                    if ownsSubwindow, let root = (Engine.getMainLoop() as? SceneTree)?.root {
                        root.addChild(node: subwindow)
                    } else if ownsSubwindow {
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
        guard app?.displayDriver == "embedded" else {
            super.layout()
            return
        }
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
        if ownsSubwindow {
            subwindow?.getParent()?.removeChild(node: subwindow)
        }
        inited = false
        subwindow = nil
        embedded = nil
        super.removeFromSuperview()
    }
}
#endif
