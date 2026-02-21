//
//  GodotAppView.swift
//
//

import OSLog
import SwiftUI
import SwiftGodot

#if os(iOS)
public struct GodotAppView: UIViewRepresentable {
    @SwiftUI.Environment(\.godotApp) var app: GodotApp?
    var view = UIGodotAppView(frame: CGRect.zero)
    let source: String?
    let scene: String?
    let onReady: ((GodotAppViewHandle) -> Void)?
    let onMessage: ((VariantDictionary) -> Void)?
    
    public init(
        source: String? = nil,
        scene: String? = nil,
        onReady: ((GodotAppViewHandle) -> Void)? = nil,
        onMessage: ((VariantDictionary) -> Void)? = nil
    ) {
        self.source = source
        self.scene = scene
        self.onReady = onReady
        self.onMessage = onMessage
    }

    public func makeUIView(context: Context) -> UIGodotAppView {
        guard let app else {
            Logger.App.error("No GodotApp instance, you must pass it on the environment using \\.godotApp")
            return view
        }

        app.configureLaunch(source: source, scene: scene)
        app.start()
        view.contentScaleFactor = UIScreen.main.scale
        view.isMultipleTouchEnabled = true
        view.app = app
        view.source = source
        view.scene = scene
        view.onReady = onReady
        view.onMessage = onMessage
        view.syncCallbackRegistration()
        return view
    }

    public func updateUIView(_ uiView: UIGodotAppView, context: Context) {
        app?.configureLaunch(source: source, scene: scene)
        uiView.source = source
        uiView.scene = scene
        uiView.onReady = onReady
        uiView.onMessage = onMessage
        uiView.syncCallbackRegistration()
        uiView.startGodotInstance()
    }
}

typealias TTGodotAppView = UIGodotAppView
typealias TTGodotWindow = UIGodotWindow

public class UIGodotAppView: UIView {
    public var renderingLayer: CAMetalLayer? = nil
    private var displayLink : CADisplayLink? = nil
    
    private var embedded: DisplayServerEmbedded?
    private var callbackToken: UUID?
    private weak var callbackApp: GodotApp?
    
    public var app: GodotApp?
    public var source: String?
    public var scene: String?
    public var onReady: ((GodotAppViewHandle) -> Void)?
    public var onMessage: ((VariantDictionary) -> Void)?

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
        syncCallbackRegistration()
        guard let app else {
            return
        }
        if renderingLayer == nil {
            commonInit()
        }
        guard let renderingLayer else {
            Logger.App.error("startGodotInstance: renderingLayer was nil")
            return
        }
        if let instance = app.instance {
            let rendererNativeSurface = RenderingNativeSurfaceApple.create(layer: UInt(bitPattern: Unmanaged.passUnretained(renderingLayer).toOpaque()))
            DisplayServerEmbedded.setNativeSurface(rendererNativeSurface)
            if !instance.isStarted() {
                instance.start()
                app.startPending()
            }
            if displayLink == nil {
                let displayLink = CADisplayLink(target: self, selector: #selector(iterate))
                displayLink.add(to: .current, forMode: RunLoop.Mode.default)
                self.displayLink = displayLink
            }
            if embedded == nil {
                embedded = DisplayServerEmbedded(nativeHandle: DisplayServer.shared.handle!)
            }
            resizeWindow()
            app.pollBridgeAndReadiness()
        } else {
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
        unregisterCallbacks()
        super.removeFromSuperview()
    }
    
    public override func didMoveToSuperview() {
        if superview == nil {
            return
        }
        if renderingLayer == nil {
            commonInit()
        }
        startGodotInstance()
    }

    @objc
    func iterate() {
        if let app, (app.isPaused || !app.isDrawing) {
            return
        }
        if let instance = app?.instance, instance.isStarted() {
            instance.iteration()
            app?.pollBridgeAndReadiness()
        }
    }

    deinit {
        unregisterCallbacks()
    }
}

private extension UIGodotAppView {
    func syncCallbackRegistration() {
        guard let app else { return }

        if callbackApp !== app {
            unregisterCallbacks()
            callbackApp = app
        }

        if callbackToken == nil {
            let token = app.registerViewCallbacks(
                handle: GodotAppViewHandle(app: app),
                onReady: { [weak self] handle in
                    self?.onReady?(handle)
                },
                onMessage: { [weak self] message in
                    self?.onMessage?(message)
                }
            )
            callbackToken = token
        }
    }

    func unregisterCallbacks() {
        callbackApp?.unregisterViewCallbacks(id: callbackToken)
        callbackToken = nil
        callbackApp = nil
    }
}
#endif
