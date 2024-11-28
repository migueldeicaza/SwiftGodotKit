//
//  GodotAppWindow.swift
//
//
#if os(iOS)

import SwiftUI
import SwiftGodot

public struct GodotWindow: UIViewRepresentable {
    @State var node: String?
    @SwiftUI.Environment(\.godotApp) var app: GodotApp?
    var view = UIGodotWindow()

    public init (callback: ((SwiftGodot.Window)->())?) {
        view.callback = callback
    }
    
    public func makeUIView(context: Context) -> UIGodotWindow {
        app?.start()
        view.contentScaleFactor = UIScreen.main.scale
        view.isMultipleTouchEnabled = true
        
        view.node = node
        view.app = app
        return view
    }
        
    public func updateUIView(_ uiView: UIGodotWindow, context: Context) {
        uiView.initGodotWindow()
    }
}

public class UIGodotWindow: UIView {
    public var windowLayer: CAMetalLayer?
    private var embedded: DisplayServerEmbedded?
    private var subwindow: SwiftGodot.Window?
    
    var callback: ((SwiftGodot.Window)->())?
    var node: String?
    var app: GodotApp?
    var inited = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func commonInit() {
        let windowLayer = CAMetalLayer()
        let size = max(UIScreen.main.bounds.size.width, UIScreen.main.bounds.size.height)
        windowLayer.frame.size = CGSize(width: size, height: size)
        windowLayer.contentsScale = self.contentScaleFactor
        windowLayer.backgroundColor = CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        layer.addSublayer(windowLayer)
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
        guard let app else { return }
        
        if (!inited) {
            if let instance = app.instance {
                if !instance.isStarted() {
                    app.queueGodotWindow(self)
                    return
                }
                if let node {
                    subwindow = ((Engine.getMainLoop() as! SceneTree).root!.findChild(pattern: node)! as! Window)
                } else {
                    subwindow = Window()
                }
                if let callback, let subwindow {
                    callback(subwindow)
                }
                let windowNativeSurface = RenderingNativeSurfaceApple.create(layer: UInt(bitPattern: Unmanaged.passUnretained(windowLayer!).toOpaque()))
                subwindow?.setNativeSurface(windowNativeSurface)
                (Engine.getMainLoop() as! SceneTree).root!.addChild(node: subwindow)
                inited = true
            } else {
                app.queueGodotWindow(self)
            }
        }
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let windowLayer, let app, app.instance != nil else { return }
        let contentsScale = windowLayer.contentsScale
        var touchData: [[String : Any]] = []
        for touch in touches {
            let touchId = app.getTouchId(touch: touch)
            if touchId == -1 {
                continue
            }
            var location = touch.location(in: self)
            if !self.layer.frame.contains(location) {
                continue
            }
            location.x -= windowLayer.frame.origin.x
            location.y -= windowLayer.frame.origin.y
            let tapCount = touch.tapCount
            touchData.append([ "touchId": touchId, "location": location, "tapCount": tapCount ])
        }
        {
            let windowId = subwindow?.getWindowId() ?? Int32(DisplayServer.mainWindowId)
            for touch in touchData {
                let touchId = touch["touchId"] as! Int
                let location = touch["location"] as! CGPoint
                let tapCount = touch["tapCount"] as! Int
                (DisplayServer.shared as! DisplayServerEmbedded).touchPress(idx: Int32(touchId), x: Int32(location.x * contentsScale), y: Int32(location.y * contentsScale), pressed: true, doubleClick: tapCount > 1, window: windowId)
            }
        }()
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let windowLayer, let app, app.instance != nil else { return }
        let contentsScale = windowLayer.contentsScale
        var touchData: [[String : Any]] = []
        for touch in touches {
            let touchId = app.getTouchId(touch: touch)
            if touchId == -1 {
                continue
            }
            var location = touch.location(in: self)
            if !self.layer.frame.contains(location) {
                continue
            }
            location.x -= windowLayer.frame.origin.x
            location.y -= windowLayer.frame.origin.y
            var prevLocation = touch.previousLocation(in: self)
            if !self.layer.frame.contains(prevLocation) {
                continue
            }
            prevLocation.x -= windowLayer.frame.origin.x
            prevLocation.y -= windowLayer.frame.origin.y
            let alt = touch.altitudeAngle
            let azim = touch.azimuthUnitVector(in: self)
            let force = touch.force
            let maximumPossibleForce = touch.maximumPossibleForce
            touchData.append([ "touchId": touchId, "location": location, "prevLocation": prevLocation, "alt": alt, "azim": azim, "force": force, "maximumPossibleForce": maximumPossibleForce ])
        }
        
        {
            let windowId = subwindow?.getWindowId() ?? Int32(DisplayServer.mainWindowId)
            for touch in touchData {
                let touchId = touch["touchId"] as! Int
                let location = touch["location"] as! CGPoint
                let prevLocation = touch["prevLocation"] as! CGPoint
                let alt = touch["alt"] as! CGFloat
                let azim = touch["azim"] as! CGVector
                let force = touch["force"] as! CGFloat
                let maximumPossibleForce = touch["maximumPossibleForce"] as! CGFloat
                (DisplayServer.shared as! DisplayServerEmbedded).touchDrag(idx: Int32(touchId), prevX: Int32(prevLocation.x  * contentsScale), prevY: Int32(prevLocation.y  * contentsScale), x: Int32(location.x * contentsScale), y: Int32(location.y * contentsScale), pressure: Double(force) / Double(maximumPossibleForce), tilt: Vector2(x: Float(azim.dx) * Float(cos(alt)), y: Float(azim.dy) * cos(Float(alt))), window: windowId)
            }
        }()
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let windowLayer, let app, app.instance != nil else { return }
        let contentsScale = windowLayer.contentsScale
        var touchData: [[String : Any]] = []
        for touch in touches {
            let touchId = app.getTouchId(touch: touch)
            if touchId == -1 {
                continue
            }
            app.removeTouchId(id: touchId)
            var location = touch.location(in: self)
            if !self.layer.frame.contains(location) {
                continue
            }
            location.x -= windowLayer.frame.origin.x
            location.y -= windowLayer.frame.origin.y
            touchData.append([ "touchId": touchId, "location": location ])
        }
        
        {
            let windowId = subwindow?.getWindowId() ?? Int32(DisplayServer.mainWindowId)
            for touch in touchData {
                let touchId = touch["touchId"] as! Int
                let location = touch["location"] as! CGPoint
                (DisplayServer.shared as! DisplayServerEmbedded).touchPress(idx: Int32(touchId), x: Int32(location.x * contentsScale), y: Int32(location.y * contentsScale), pressed: false, doubleClick: false, window: windowId)
            }
        }()
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let app, app.instance != nil else { return }

        var touchData: [[String : Any]] = []
        for touch in touches {
            let touchId = app.getTouchId(touch: touch)
            if touchId == -1 {
                continue
            }
            app.removeTouchId(id: touchId)
            touchData.append([ "touchId": touchId ])
        }
        
        {
            let windowId = subwindow?.getWindowId() ?? Int32(DisplayServer.mainWindowId)
            for touch in touchData {
                let touchId = touch["touchId"] as! Int
                (DisplayServer.shared as! DisplayServerEmbedded).touchesCanceled(idx: Int32(touchId), window: windowId)
            }
        }()
    }
    
    func resizeWindow() {
        if let embedded, let subwindow {
            embedded.resizeWindow(size: Vector2i(x: Int32(self.bounds.size.width * self.contentScaleFactor), y: Int32(self.bounds.size.height * self.contentScaleFactor)), id: subwindow.getWindowId())
        }
    }
    
    public override func layoutSubviews() {
        self.windowLayer?.frame = self.bounds
        if inited {
            if embedded == nil {
                embedded = DisplayServerEmbedded(nativeHandle: DisplayServer.shared.handle!)
            }
            resizeWindow()
        }
        super.layoutSubviews()
    }
    
    public override func didMoveToSuperview() {
        commonInit()
        initGodotWindow()
    }
    
    public override func removeFromSuperview() {
        if let subwindow {
            subwindow.getParent()?.removeChild(node: subwindow)
        }
    }
}
#endif
