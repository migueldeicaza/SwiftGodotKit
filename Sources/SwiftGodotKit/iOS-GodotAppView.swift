//
//  GodotAppView.swift
//
//

import OSLog
import QuartzCore
import SwiftUI
import SwiftGodot
import libgodot

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
    var isAttachedForStartup: Bool { superview != nil }
    public var renderingLayer: CALayer? = nil
    private var displayLink : CADisplayLink? = nil
    private var didInitializeRenderingLayer = false
    
    private var embedded: DisplayServerAppleEmbeddedBridge.Handle?
    private var callbackToken: UUID?
    private weak var callbackApp: GodotApp?
    private var didEmitDisplayServerNotEmbeddedWarning = false
    
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
        guard let app else {
            Logger.App.error("commonInit: GodotApp was nil")
            return
        }
        let layerPointer = app.renderingDriver.withCString {
            libgodot.libgodot_ios_create_rendering_layer($0)
        }
        guard let layerPointer else {
            Logger.App.error("commonInit: unsupported rendering driver \(app.renderingDriver, privacy: .public)")
            return
        }
        let renderingLayer = Unmanaged<CALayer>.fromOpaque(layerPointer).takeRetainedValue()
        let size = max(UIScreen.main.bounds.size.width, UIScreen.main.bounds.size.height)
        renderingLayer.frame.size = CGSize(width: size, height: size)
        renderingLayer.contentsScale = self.contentScaleFactor
        
        layer.addSublayer(renderingLayer)
        self.renderingLayer = renderingLayer
    }
    
    deinit {
        renderingLayer?.removeFromSuperlayer()
        unregisterCallbacks()
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
        
        DisplayServerAppleEmbeddedBridge.resizeWindow(
            embedded,
            size: Vector2i(x: Int32(self.bounds.size.width * self.contentScaleFactor), y: Int32(self.bounds.size.height * self.contentScaleFactor)),
            id: Int32(DisplayServer.mainWindowId)
        )
    }

    public override func layoutSubviews() {
        if let renderingLayer {
            renderingLayer.frame = self.bounds
            if didInitializeRenderingLayer {
                let layerPointer = Unmanaged.passUnretained(renderingLayer).toOpaque()
                libgodot.libgodot_ios_layout_rendering_layer(layerPointer)
            }
        }
        if let app, app.isEngineRunning {
            if embedded == nil {
                if let displayServer = DisplayServerAppleEmbeddedBridge.getSingleton() {
                    embedded = displayServer
                } else {
                    emitDisplayServerNotEmbeddedWarning(context: "layoutSubviews")
                }
            }
            if embedded != nil {
                resizeWindow()
            }
        }
        super.layoutSubviews()
    }
    
    func startGodotInstance() {
        syncCallbackRegistration()
        guard let app else { return }
        app.beginEngineOperation()
        defer { app.endEngineOperation() }
        let action = app.beginViewStartup(self)
        switch action {
        case .wait, .failed:
            return
        case .prepare, .running:
            break
        }
        if renderingLayer == nil {
            commonInit()
        }
        guard let renderingLayer else {
            Logger.App.error("startGodotInstance: renderingLayer was nil")
            if case .prepare = action {
                _ = app.completeSurfacePreparation(for: self, succeeded: false)
            }
            return
        }
        let layerPointer = Unmanaged.passUnretained(renderingLayer).toOpaque()
        if !didInitializeRenderingLayer {
            libgodot.libgodot_ios_initialize_rendering_layer(layerPointer)
            didInitializeRenderingLayer = true
        }
        let surface = RenderingNativeSurfaceApple.create(layer: UInt(bitPattern: layerPointer))
        DisplayServerAppleEmbeddedBridge.setNativeSurface(surface)
        if case .prepare = action {
            guard app.completeSurfacePreparation(for: self, succeeded: true) else { return }
        } else {
            app.runningViewDidBindSurface(self)
        }
        if displayLink == nil {
            let displayLink = CADisplayLink(target: self, selector: #selector(iterate))
            displayLink.add(to: .current, forMode: RunLoop.Mode.default)
            self.displayLink = displayLink
        }
        if embedded == nil {
            if let displayServer = DisplayServerAppleEmbeddedBridge.getSingleton() {
                embedded = displayServer
            } else {
                emitDisplayServerNotEmbeddedWarning(context: "startGodotInstance")
            }
        }
        if embedded != nil {
            resizeWindow()
        }
        app.pollBridgeAndReadiness()
    }

    func engineDidStop() {
        displayLink?.invalidate()
        displayLink = nil
        embedded = nil
        renderingLayer?.removeFromSuperlayer()
        renderingLayer = nil
        didInitializeRenderingLayer = false
        didEmitDisplayServerNotEmbeddedWarning = false
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let app, app.isEngineRunning, let renderingLayer else { return }
        let contentsScale = renderingLayer.contentsScale
        
        var touchData: [[String : Any]] = []
        for touch in touches {
            var location = touch.location(in: self)
            if !bounds.contains(location) {
                continue
            }
            let touchId = app.getTouchId(touch: touch)
            if touchId == -1 {
                continue
            }
            location.x -= renderingLayer.frame.origin.x
            location.y -= renderingLayer.frame.origin.y
            let tapCount = touch.tapCount
            touchData.append([ "touchId": touchId, "location": location, "tapCount": tapCount ])
        }
        app.performEngineOperation {
            let windowId = Int32(DisplayServer.mainWindowId)
            for touch in touchData {
                guard let touchId = touch["touchId"] as? Int,
                      let location = touch["location"] as? CGPoint,
                      let tapCount = touch["tapCount"] as? Int,
                      let displayServer = DisplayServerAppleEmbeddedBridge.getSingleton()
                else { continue }
                
                DisplayServerAppleEmbeddedBridge.touchPress(
                    displayServer,
                    idx: Int32(touchId),
                    x: Int32(location.x * contentsScale),
                    y: Int32(location.y * contentsScale),
                    pressed: true,
                    doubleClick: tapCount > 1,
                    window: windowId
                )
            }
        }
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let app, let renderingLayer, app.isEngineRunning else { return }
        let contentsScale = renderingLayer.contentsScale
        
        var touchData: [[String : Any]] = []
        for touch in touches {
            let touchId = app.getTouchId(touch: touch)
            if touchId == -1 {
                continue
            }
            var location = touch.location(in: self)
            location.x -= renderingLayer.frame.origin.x
            location.y -= renderingLayer.frame.origin.y
            var prevLocation = touch.previousLocation(in: self)
            prevLocation.x -= renderingLayer.frame.origin.x
            prevLocation.y -= renderingLayer.frame.origin.y
            let alt = touch.altitudeAngle
            let azim = touch.azimuthUnitVector(in: self)
            let force = touch.force
            let maximumPossibleForce = touch.maximumPossibleForce
            touchData.append([ "touchId": touchId, "location": location, "prevLocation": prevLocation, "alt": alt, "azim": azim, "force": force, "maximumPossibleForce": maximumPossibleForce ])
        }
        
        app.performEngineOperation {
            let windowId = Int32(DisplayServer.mainWindowId)
            for touch in touchData {
                guard let touchId = touch["touchId"] as? Int,
                      let location = touch["location"] as? CGPoint,
                      let prevLocation = touch["prevLocation"] as? CGPoint,
                      let alt = touch["alt"] as? CGFloat,
                      let azim = touch["azim"] as? CGVector,
                      let force = touch["force"] as? CGFloat,
                      let maximumPossibleForce = touch["maximumPossibleForce"] as? CGFloat,
                      let displayServer = DisplayServerAppleEmbeddedBridge.getSingleton() else { continue }
                DisplayServerAppleEmbeddedBridge.touchDrag(displayServer, idx: Int32(touchId), prevX: Int32(prevLocation.x  * contentsScale), prevY: Int32(prevLocation.y  * contentsScale), x: Int32(location.x * contentsScale), y: Int32(location.y * contentsScale), pressure: Double(force) / Double(maximumPossibleForce), tilt: Vector2(x: Float(azim.dx) * Float(cos(alt)), y: Float(azim.dy) * cos(Float(alt))), window: windowId)
            }
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let app, let renderingLayer, app.isEngineRunning else { return }
        let contentsScale = renderingLayer.contentsScale
        
        var touchData: [[String : Any]] = []
        for touch in touches {
            let touchId = app.getTouchId(touch: touch)
            if touchId == -1 {
                continue
            }
            var location = touch.location(in: self)
            app.removeTouchId(id: touchId)
            location.x -= renderingLayer.frame.origin.x
            location.y -= renderingLayer.frame.origin.y
            touchData.append([ "touchId": touchId, "location": location ])
        }
        
        app.performEngineOperation {
            let windowId = Int32(DisplayServer.mainWindowId)
            for touch in touchData {
                guard let touchId = touch["touchId"] as? Int,
                      let location = touch["location"] as? CGPoint,
                      let displayServer = DisplayServerAppleEmbeddedBridge.getSingleton() else { continue }
                DisplayServerAppleEmbeddedBridge.touchPress(
                    displayServer,
                    idx: Int32(touchId),
                    x: Int32(location.x * contentsScale),
                    y: Int32(location.y * contentsScale),
                    pressed: false,
                    doubleClick: false,
                    window: windowId
                )
            }
        }
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let app, app.isEngineRunning else { return }
        var touchData: [[String : Any]] = []
        for touch in touches {
            let touchId = app.getTouchId(touch: touch)
            if touchId == -1 {
                continue
            }
            app.removeTouchId(id: touchId)
            touchData.append([ "touchId": touchId ])
        }
        
        app.performEngineOperation {
            let windowId = Int32(DisplayServer.mainWindowId)
            for touch in touchData {
                guard let touchId = touch["touchId"] as? Int,
                      let displayServer = DisplayServerAppleEmbeddedBridge.getSingleton() else { continue }
                
                DisplayServerAppleEmbeddedBridge.touchesCanceled(displayServer, idx: Int32(touchId), window: windowId)
            }
        }
    }
    
    public override func removeFromSuperview() {
        displayLink?.invalidate()
        displayLink = nil
        unregisterCallbacks()
        app?.removePending(self)
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
        if let app, app.isEngineRunning, let instance = app.instance {
            app.performEngineOperation {
                if let renderingLayer {
                    let layerPointer = Unmanaged.passUnretained(renderingLayer).toOpaque()
                    libgodot.libgodot_ios_start_rendering_layer(layerPointer)
                    _ = instance.iteration()
                    libgodot.libgodot_ios_stop_rendering_layer(layerPointer)
                } else {
                    _ = instance.iteration()
                }
            }
            app.pollBridgeAndReadiness()
        }
    }
}

private extension UIGodotAppView {
    func emitDisplayServerNotEmbeddedWarning(context: String) {
        guard !didEmitDisplayServerNotEmbeddedWarning else { return }
        didEmitDisplayServerNotEmbeddedWarning = true
        let detail = "DisplayServer.shared is not DisplayServerAppleEmbedded (\(context))"
        Logger.App.error("\(detail, privacy: .public)")
        app?.emitRuntimeEvent(
            .warning(
                GodotWarningEvent(
                    code: .displayServerNotEmbedded,
                    detail: detail
                )
            )
        )
    }

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
