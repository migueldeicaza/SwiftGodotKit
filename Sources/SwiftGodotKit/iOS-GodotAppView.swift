//
//  GodotAppView.swift
//
//

import SwiftUI
import SwiftGodot

#if os(iOS)
public struct GodotAppView: UIViewRepresentable {
    var view = UIGodotAppView(frame: CGRect.zero)
    let app: GodotApp
    
    public init(app: GodotApp) {
        self.app = app
    }

    public func makeUIView(context: Context) -> UIGodotAppView {
        app.start()
        view.contentScaleFactor = UIScreen.main.scale
        view.isMultipleTouchEnabled = true
        view.app = app
        return view
    }

    public func updateUIView(_ uiView: UIGodotAppView, context: Context) {
        uiView.startGodotInstance()
    }
}

typealias TTGodotAppView = UIGodotAppView
typealias TTGodotWindow = UIGodotWindow

public class UIGodotAppView: UIView {
    public var renderingLayer: CAMetalLayer? = nil
    private var displayLink : CADisplayLink? = nil
    
    private var embedded: DisplayServerEmbedded?
    
    public var app: GodotApp?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func commonInit() {
        let renderingLayer = CAMetalLayer()
        let size = max(UIScreen.main.bounds.size.width, UIScreen.main.bounds.size.height)
        renderingLayer.frame.size = CGSize(width: size, height: size)
        renderingLayer.contentsScale = self.contentScaleFactor
        
        layer.addSublayer(renderingLayer)
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
        guard let embedded else {
            logger.error("UIGodotApPView.resizeWindow invoked with no embedded window")
            return
        }
        
        embedded.resizeWindow(
            size: Vector2i(x: Int32(self.bounds.size.width * self.contentScaleFactor), y: Int32(self.bounds.size.height * self.contentScaleFactor)),
            id: Int32(DisplayServer.mainWindowId)
        )
    }

    public override func layoutSubviews() {
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
        }
        super.layoutSubviews()
    }
    
    func startGodotInstance() {
        if let instance = app?.instance {
            if !instance.isStarted() {
                let rendererNativeSurface = RenderingNativeSurfaceApple.create(layer: UInt(bitPattern: Unmanaged.passUnretained(renderingLayer!).toOpaque()))
                DisplayServerEmbedded.setNativeSurface(rendererNativeSurface)
                instance.start()
                let displayLink = CADisplayLink(target: self, selector: #selector(iterate))
                displayLink.add(to: .current, forMode: RunLoop.Mode.default)
                self.displayLink = displayLink
            }
        } else if let app {
            app.queueStart(self)
        }
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let app, let instance = app.instance, let renderingLayer else { return }
        let contentsScale = renderingLayer.contentsScale
        
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
            location.x -= renderingLayer.frame.origin.x
            location.y -= renderingLayer.frame.origin.y
            let tapCount = touch.tapCount
            touchData.append([ "touchId": touchId, "location": location, "tapCount": tapCount ])
        }
        {
            let windowId = Int32(DisplayServer.mainWindowId)
            for touch in touchData {
                guard let touchId = touch["touchId"] as? Int,
                      let location = touch["location"] as? CGPoint,
                      let tapCount = touch["tapCount"] as? Int,
                      let displayServer = DisplayServer.shared as? DisplayServerEmbedded
                else { continue }
                
                displayServer.touchPress (
                    idx: Int32(touchId),
                    x: Int32(location.x * contentsScale),
                    y: Int32(location.y * contentsScale),
                    pressed: true,
                    doubleClick: tapCount > 1,
                    window: windowId
                )
            }
        }()
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let app, let renderingLayer, let instance = app.instance else { return }
        let contentsScale = renderingLayer.contentsScale
        
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
            location.x -= renderingLayer.frame.origin.x
            location.y -= renderingLayer.frame.origin.y
            var prevLocation = touch.previousLocation(in: self)
            if !self.layer.frame.contains(prevLocation) {
                continue
            }
            prevLocation.x -= renderingLayer.frame.origin.x
            prevLocation.y -= renderingLayer.frame.origin.y
            let alt = touch.altitudeAngle
            let azim = touch.azimuthUnitVector(in: self)
            let force = touch.force
            let maximumPossibleForce = touch.maximumPossibleForce
            touchData.append([ "touchId": touchId, "location": location, "prevLocation": prevLocation, "alt": alt, "azim": azim, "force": force, "maximumPossibleForce": maximumPossibleForce ])
        }
        
        {
            let windowId = Int32(DisplayServer.mainWindowId)
            for touch in touchData {
                guard let touchId = touch["touchId"] as? Int,
                      let location = touch["location"] as? CGPoint,
                      let prevLocation = touch["prevLocation"] as? CGPoint,
                      let alt = touch["alt"] as? CGFloat,
                      let azim = touch["azim"] as? CGVector,
                      let force = touch["force"] as? CGFloat,
                      let maximumPossibleForce = touch["maximumPossibleForce"] as? CGFloat,
                      let displayServer = DisplayServer.shared as? DisplayServerEmbedded else { continue }
                displayServer.touchDrag(idx: Int32(touchId), prevX: Int32(prevLocation.x  * contentsScale), prevY: Int32(prevLocation.y  * contentsScale), x: Int32(location.x * contentsScale), y: Int32(location.y * contentsScale), pressure: Double(force) / Double(maximumPossibleForce), tilt: Vector2(x: Float(azim.dx) * Float(cos(alt)), y: Float(azim.dy) * cos(Float(alt))), window: windowId)
            }
        }()
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let app, let renderingLayer, let instance = app.instance else { return }
        let contentsScale = renderingLayer.contentsScale
        
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
            location.x -= renderingLayer.frame.origin.x
            location.y -= renderingLayer.frame.origin.y
            touchData.append([ "touchId": touchId, "location": location ])
        }
        
        {
            let windowId = Int32(DisplayServer.mainWindowId)
            for touch in touchData {
                guard let touchId = touch["touchId"] as? Int,
                      let location = touch["location"] as? CGPoint,
                      let displayServer = DisplayServer.shared as? DisplayServerEmbedded else { continue }
                displayServer.touchPress (
                    idx: Int32(touchId),
                    x: Int32(location.x * contentsScale),
                    y: Int32(location.y * contentsScale),
                    pressed: false,
                    doubleClick: false,
                    window: windowId
                )
            }
        }()
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let app, let instance = app.instance else { return }
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
            let windowId = Int32(DisplayServer.mainWindowId)
            for touch in touchData {
                guard let touchId = touch["touchId"] as? Int,
                      let displayServer = DisplayServer.shared as? DisplayServerEmbedded else { continue }
                
                displayServer.touchesCanceled(idx: Int32(touchId), window: windowId)
            }
        }()
    }
    
    public override func removeFromSuperview() {
        displayLink?.invalidate()
        displayLink = nil
        
        if let instance = app?.instance {
            GodotInstance.destroy(instance: instance)
        }
    }
    
    public override func didMoveToSuperview() {
        commonInit()
        startGodotInstance()
    }

    @objc
    func iterate() {
        if let instance = app?.instance {
            if instance.isStarted() {
                instance.iteration()
            }
        }
    }
}
#endif
