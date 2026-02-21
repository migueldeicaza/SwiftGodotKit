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
    private var boundWindowInstanceId: Int64?
    private var ownsSubwindow = false
    private var didLogMissingNamedWindow = false
    
    var callback: ((SwiftGodot.Window)->())?
    var node: String?
    var app: GodotApp?
    var inited = false
    
    public override var windowId: Int {
        guard inited, isBoundWindowAlive(), let subwindow else {
            return Int(Int32(DisplayServer.invalidWindowId))
        }
        return Int(subwindow.getWindowId())
    }
    
    func initGodotWindow() {
        guard app?.displayDriver == "embedded" else {
            return
        }
        guard let app else { return }
        guard let instance = app.instance else {
            app.queueGodotWindow(self)
            return
        }
        guard instance.isStarted() else {
            app.queueGodotWindow(self)
            return
        }

        if let node {
            bindNamedWindow(node: node, app: app)
            return
        }

        if inited {
            if !isBoundWindowAlive() {
                clearBinding(removeOwnedWindow: false)
                app.queueGodotWindow(self)
            }
            return
        }

        guard (Engine.getMainLoop() as? SceneTree)?.root != nil else {
            app.queueGodotWindow(self)
            return
        }
        let createdWindow = SwiftGodot.Window()
        if !attach(window: createdWindow, ownsWindow: true) {
            app.queueGodotWindow(self)
        }
    }
    
    public override func layout() {
        guard app?.displayDriver == "embedded" else {
            super.layout()
            return
        }
        initGodotWindow()
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
        clearBinding(removeOwnedWindow: true)
        embedded = nil
        super.removeFromSuperview()
    }

    private func bindNamedWindow(node: String, app: GodotApp) {
        if inited && isBoundWindowAlive() {
            return
        }

        guard let namedWindow = findNamedWindow(named: node) else {
            if !didLogMissingNamedWindow {
                logger.error("initGodotWindow: missing window named \(node, privacy: .public)")
                didLogMissingNamedWindow = true
            }
            clearBinding(removeOwnedWindow: true)
            app.queueGodotWindow(self)
            return
        }

        clearBinding(removeOwnedWindow: true)
        _ = attach(window: namedWindow, ownsWindow: false)
    }

    private func findNamedWindow(named: String) -> SwiftGodot.Window? {
        (Engine.getMainLoop() as? SceneTree)?.root?.findChild(pattern: named) as? SwiftGodot.Window
    }

    @discardableResult
    private func attach(window: SwiftGodot.Window, ownsWindow: Bool) -> Bool {
        guard let renderingLayer else {
            logger.critical("GodotWindow.renderingLayer was not initialized")
            return false
        }

        if ownsWindow {
            guard let root = (Engine.getMainLoop() as? SceneTree)?.root else {
                logger.error("initGodotWindow: could not turn Engine.mainLoop into a sceneTree")
                return false
            }
            if window.getParent() == nil {
                root.addChild(node: window)
            }
        }

        let windowNativeSurface = RenderingNativeSurfaceApple.create(layer: UInt(bitPattern: Unmanaged.passUnretained(renderingLayer).toOpaque()))
        window.setNativeSurface(windowNativeSurface)

        subwindow = window
        ownsSubwindow = ownsWindow
        boundWindowInstanceId = windowInstanceId(window)
        inited = true
        didLogMissingNamedWindow = false

        if let callback {
            callback(window)
        }
        return true
    }

    private func clearBinding(removeOwnedWindow: Bool) {
        if removeOwnedWindow, ownsSubwindow, let subwindow, isBoundWindowAlive() {
            subwindow.getParent()?.removeChild(node: subwindow)
        }
        inited = false
        subwindow = nil
        boundWindowInstanceId = nil
        ownsSubwindow = false
    }

    private func windowInstanceId(_ window: SwiftGodot.Window) -> Int64 {
        Int64(bitPattern: UInt64(window.getInstanceId()))
    }

    private func isBoundWindowAlive() -> Bool {
        guard let boundWindowInstanceId else { return false }
        return GD.isInstanceIdValid(id: boundWindowInstanceId)
    }
}
#endif
