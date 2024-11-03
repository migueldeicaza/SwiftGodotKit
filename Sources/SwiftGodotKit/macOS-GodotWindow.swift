//
//  GodotAppWindow.swift
//
//
#if os(macOS)
import SwiftUI
import SwiftGodot

public struct GodotWindow: NSViewRepresentable {
    @EnvironmentObject var app: GodotApp
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

public class NSGodotWindow: NSView {
    public var windowLayer: CAMetalLayer?
    private var embedded: DisplayServerEmbedded?
    private var subwindow: SwiftGodot.Window?
    
    var callback: ((SwiftGodot.Window)->())?
    var node: String?
    var app: GodotApp?
    var inited = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        wantsLayer = true
        let windowLayer = CAMetalLayer()
        windowLayer.frame = bounds
        windowLayer.contentsScale = 1
        windowLayer.backgroundColor = CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        layer?.addSublayer(windowLayer)
        self.windowLayer = windowLayer
    }
    
    public override var bounds: CGRect {
        didSet {
            windowLayer?.frame = self.bounds
            resizeWindow()
        }
    }
    
    deinit {
        windowLayer?.removeFromSuperlayer()
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
                guard let windowLayer else {
                    logger.critical("GodotWindow.windowLayer was not initialized")
                    return
                }
                
                if let subwindow {
                    if let callback {
                        callback(subwindow)
                    }
                    let windowNativeSurface = RenderingNativeSurfaceApple.create(layer: UInt(bitPattern: Unmanaged.passUnretained(windowLayer).toOpaque()))
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

    func resizeWindow() {
        if let embedded, let subwindow {
            // BUG: the -1 is because we do not have embedding support yet
            if subwindow.getWindowId() <= 0 {
                print ("GodotWindow.resizeWindow: not ready to resize")
                return
            }
            embedded.resizeWindow(size: Vector2i(x: Int32(self.bounds.size.width), y: Int32(self.bounds.size.height)), id: subwindow.getWindowId())
        }
    }
    
    public override func layout() {
        windowLayer?.frame = self.bounds
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
    }


    var mouseDownControl: Bool = false
    override public func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            mouseDownControl = true
            processEvent(event: event, index: .right, pressed: true, outOfStream: false)
        } else {
            mouseDownControl = false
            processEvent(event: event, index: .left, pressed: true, outOfStream: false)
        }
    }

    override public func mouseUp(with event: NSEvent) {
        if mouseDownControl {
            processEvent(event: event, index: .right, pressed: false, outOfStream: false)
        } else {
            processEvent(event: event, index: .left, pressed: false, outOfStream: false)
        }
    }

    func processEvent(event: NSEvent, index: MouseButton, pressed: Bool, outOfStream: Bool) {
        let windowId = Int32(DisplayServer.mainWindowId)
        let mb = InputEventMouseButton()
        mb.windowId = Int(windowId)
        mb.buttonIndex = index == .left ? MouseButton.left : index == .right ? MouseButton.right : .none

        mb.pressed = pressed
        let local = event.locationInWindow

        let scale = window?.backingScaleFactor ?? 1.0

        let vpos = Vector2(x: Float(local.x/scale), y: Float(local.y/scale))
        mb.globalPosition = vpos
        mb.position = vpos
        print ("\(vpos)")
        var mask: MouseButtonMask = []
        if index == .left {
            mask = [.left]
        } else if index == .right {
            mask = [.right]
        } else if index == .middle {
            mask = [.middle]
        }
        mb.buttonMask = mask
        if !outOfStream && index == .left && pressed {
            mb.doubleClick = event.clickCount == 2
        }
        Input.parseInputEvent(mb)
    }
}
#endif
