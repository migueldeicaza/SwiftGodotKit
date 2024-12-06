//
//  MacOS/GodotAppView.swift
//
//

import OSLog
import SwiftUI
import SwiftGodot
#if os(macOS)
public struct GodotAppView: NSViewRepresentable {
    var view = NSGodotAppView(frame: CGRect.zero)
    @SwiftUI.Environment(\.godotApp) var app: GodotApp?

    public init () { }
    
    public func makeNSView(context: Context) -> NSGodotAppView {
        guard let app else {
            Logger.App.error("No GodotApp instance")
            return view
        }
        
        view.app = app
        return view
    }

    public func updateNSView(_ nsView: NSGodotAppView, context: Context) {
        nsView.startGodotInstance()
    }
}

typealias TTGodotAppView = NSGodotAppView
typealias TTGodotWindow = NSGodotWindow

public class NSGodotAppView: NSView {
    public var renderingLayer: CAMetalLayer? = nil
    private var link : CADisplayLink? = nil
    private var embedded: DisplayServerEmbedded?
    
    public var app: GodotApp?

    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }
    
    private func commonInit() {
        let renderingLayer = CAMetalLayer()
        renderingLayer.frame.size = frame.size
        
        layer?.addSublayer(renderingLayer)
        self.renderingLayer = renderingLayer
    }
    
    deinit {
        renderingLayer?.removeFromSuperlayer()
    }
    
    public override var bounds: CGRect {
        didSet {
            resizeWindow()
        }
    }

    func resizeWindow() {
        guard let embedded else { return }
//        guard DisplayServer.mainWindowId != 0 else {
//            print ("Can not resize yet")
//            return
//        }
        
        embedded.resizeWindow(
            size: Vector2i(x: Int32(self.bounds.size.width), y: Int32(self.bounds.size.height)),
            id: Int32(DisplayServer.mainWindowId)
        )
    }
    
    public override func layout() {
        if let renderingLayer {
            renderingLayer.frame = self.bounds
        }
        if let instance = app?.instance {
            if instance.isStarted() {
                if embedded == nil {
                    embedded = DisplayServerEmbedded(nativeHandle: DisplayServer.shared.handle!)
                }
                
                resizeWindow()
            }
        } else if let app {
            app.queueLayout(self)
        }
        super.layout()
    }

    func startGodotInstance() {
        if let instance = app?.instance {
            if !instance.isStarted() {
                let rendererNativeSurface = RenderingNativeSurfaceApple.create(layer: UInt(bitPattern: Unmanaged.passUnretained(renderingLayer!).toOpaque()))
                DisplayServerEmbedded.setNativeSurface(rendererNativeSurface)
                _ = instance.start()
                let link = displayLink(target: self, selector: #selector(iterate))
                link.add(to: .current, forMode: RunLoop.Mode.default)
                self.link = link
                
                if let delegate = app?.appDelegate {
                    NSApplication.shared.delegate = delegate
                }
            }
        } else if let app {
            app.queueStart(self)
        }
    }
    
    public override func removeFromSuperview() {
        link?.invalidate()
        link = nil
        
        if let instance = app?.instance {
            GodotInstance.destroy(instance: instance)
        }
    }
    
    public override func viewDidMoveToSuperview() {
        commonInit()
    }
    
    public override func viewDidMoveToWindow() {
        // It seems doing this in viewDidMoveToSuperview is too early to start the Godot app.
        if window != nil {
            app?.start()
        }
    }
    
    @objc
    func iterate() {
        if let instance = app?.instance {
            if instance.isStarted() {
                _ = instance.iteration()
            }
        }
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
