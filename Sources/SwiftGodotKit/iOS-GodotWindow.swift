//
//  GodotAppWindow.swift
//
//
#if os(iOS)

import OSLog
import SwiftUI
import SwiftGodot

public struct GodotWindow: UIViewRepresentable {
    let node: String?
    @SwiftUI.Environment(\.godotApp) var app: GodotApp?
    var view = UIGodotWindow()

    public init(node: String? = nil, callback: ((SwiftGodot.Window)->())?) {
        self.node = node
        view.callback = callback
    }
    
    public func makeUIView(context: Context) -> UIGodotWindow {
        guard let app else {
            Logger.Window.error("No GodotApp instance")
            return view
        }
        
        app.start()
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
    private var boundWindowInstanceId: Int64?
    
    var callback: ((SwiftGodot.Window)->())?
    var node: String?
    var app: GodotApp?
    var inited = false
    private var ownsSubwindow = false
    private var didLogMissingNamedWindow = false
    private var didLogMissingSetNativeSurface = false
    
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
        if windowLayer == nil {
            commonInit()
        }

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
            app.queueGodotWindow(self)
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
        let createdWindow = Window()
        if !attach(window: createdWindow, ownsWindow: true, state: .bound) {
            app.queueGodotWindow(self)
        }
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let windowLayer, let app, app.instance != nil else { return }
        guard let windowId = targetWindowIdForInput(), let displayServer = DisplayServer.shared as? DisplayServerEmbedded else { return }
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
        for touch in touchData {
            let touchId = touch["touchId"] as! Int
            let location = touch["location"] as! CGPoint
            let tapCount = touch["tapCount"] as! Int
            displayServer.touchPress(idx: Int32(touchId), x: Int32(location.x * contentsScale), y: Int32(location.y * contentsScale), pressed: true, doubleClick: tapCount > 1, window: windowId)
        }
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let windowLayer, let app, app.instance != nil else { return }
        guard let windowId = targetWindowIdForInput(), let displayServer = DisplayServer.shared as? DisplayServerEmbedded else { return }
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
        
        for touch in touchData {
            let touchId = touch["touchId"] as! Int
            let location = touch["location"] as! CGPoint
            let prevLocation = touch["prevLocation"] as! CGPoint
            let alt = touch["alt"] as! CGFloat
            let azim = touch["azim"] as! CGVector
            let force = touch["force"] as! CGFloat
            let maximumPossibleForce = touch["maximumPossibleForce"] as! CGFloat
            displayServer.touchDrag(idx: Int32(touchId), prevX: Int32(prevLocation.x  * contentsScale), prevY: Int32(prevLocation.y  * contentsScale), x: Int32(location.x * contentsScale), y: Int32(location.y * contentsScale), pressure: Double(force) / Double(maximumPossibleForce), tilt: Vector2(x: Float(azim.dx) * Float(cos(alt)), y: Float(azim.dy) * cos(Float(alt))), window: windowId)
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let windowLayer, let app, app.instance != nil else { return }
        guard let windowId = targetWindowIdForInput(), let displayServer = DisplayServer.shared as? DisplayServerEmbedded else { return }
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
        
        for touch in touchData {
            let touchId = touch["touchId"] as! Int
            let location = touch["location"] as! CGPoint
            displayServer.touchPress(idx: Int32(touchId), x: Int32(location.x * contentsScale), y: Int32(location.y * contentsScale), pressed: false, doubleClick: false, window: windowId)
        }
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let app, app.instance != nil else { return }
        guard let windowId = targetWindowIdForInput(), let displayServer = DisplayServer.shared as? DisplayServerEmbedded else { return }

        var touchData: [[String : Any]] = []
        for touch in touches {
            let touchId = app.getTouchId(touch: touch)
            if touchId == -1 {
                continue
            }
            app.removeTouchId(id: touchId)
            touchData.append([ "touchId": touchId ])
        }
        
        for touch in touchData {
            let touchId = touch["touchId"] as! Int
            displayServer.touchesCanceled(idx: Int32(touchId), window: windowId)
        }
    }
    
    func resizeWindow() {
        if let embedded, let subwindow, inited, isBoundWindowAlive() {
            embedded.resizeWindow(size: Vector2i(x: Int32(self.bounds.size.width * self.contentScaleFactor), y: Int32(self.bounds.size.height * self.contentScaleFactor)), id: subwindow.getWindowId())
        }
    }
    
    public override func layoutSubviews() {
        self.windowLayer?.frame = self.bounds
        initGodotWindow()
        if inited {
            if embedded == nil {
                embedded = DisplayServer.shared as? DisplayServerEmbedded
            }
            resizeWindow()
        }
        super.layoutSubviews()
    }
    
    public override func didMoveToSuperview() {
        if superview == nil {
            return
        }
        if windowLayer == nil {
            commonInit()
        }
        initGodotWindow()
    }
    
    public override func removeFromSuperview() {
        clearBinding(removeOwnedWindow: true)
        embedded = nil
        super.removeFromSuperview()
    }

    private func targetWindowIdForInput() -> Int32? {
        initGodotWindow()
        guard inited, isBoundWindowAlive(), let subwindow else { return nil }
        return subwindow.getWindowId()
    }

    private func bindNamedWindow(node: String, app: GodotApp) {
        guard let namedWindow = findNamedWindow(named: node) else {
            if !didLogMissingNamedWindow {
                Logger.Window.error("initGodotWindow: could not find window named \(node, privacy: .public)")
                app.emitRuntimeEvent(
                    .windowBinding(
                        GodotWindowBindingEvent(
                            state: .missingNamedWindow,
                            nodeName: node,
                            instanceId: nil,
                            ownsWindow: false,
                            platform: "ios"
                        )
                    )
                )
                didLogMissingNamedWindow = true
            }
            clearBinding(removeOwnedWindow: true)
            app.queueGodotWindow(self)
            return
        }

        let namedWindowInstanceId = windowInstanceId(namedWindow)
        let shouldRebind = !inited || !isBoundWindowAlive() || boundWindowInstanceId != namedWindowInstanceId
        guard shouldRebind else { return }
        let bindingState: GodotWindowBindingEvent.State = (inited && isBoundWindowAlive()) ? .rebound : .bound

        clearBinding(removeOwnedWindow: true)
        _ = attach(window: namedWindow, ownsWindow: false, state: bindingState)
    }

    private func findNamedWindow(named: String) -> Window? {
        guard
            let sceneTree = Engine.getMainLoop() as? SceneTree,
            let root = sceneTree.root
        else {
            return nil
        }
        return root.findChild(pattern: named, recursive: true, owned: false) as? Window
    }

    @discardableResult
    private func attach(
        window: Window,
        ownsWindow: Bool,
        state: GodotWindowBindingEvent.State
    ) -> Bool {
        guard let windowLayer else {
            Logger.Window.error("initGodotWindow: windowLayer was nil")
            return false
        }

        if ownsWindow {
            guard
                let sceneTree = Engine.getMainLoop() as? SceneTree,
                let root = sceneTree.root
            else {
                Logger.Window.error("initGodotWindow: could not access scene tree root for new subwindow")
                return false
            }
            if window.getParent() == nil {
                root.addChild(node: window)
            }
        }

        let setNativeSurfaceMethod = StringName("set_native_surface")
        if window.hasMethod(setNativeSurfaceMethod) {
            let windowNativeSurface = RenderingNativeSurfaceApple.create(layer: UInt(bitPattern: Unmanaged.passUnretained(windowLayer).toOpaque()))
            window.setNativeSurface(windowNativeSurface)
        } else if !didLogMissingSetNativeSurface {
            Logger.Window.error("attach(window:): Window is missing set_native_surface in this runtime; skipping native surface binding")
            app?.emitRuntimeEvent(
                .warning(
                    GodotWarningEvent(
                        code: .windowNativeSurfaceUnsupported,
                        detail: "Window is missing set_native_surface; skipping native surface binding"
                    )
                )
            )
            app?.emitRuntimeEvent(
                .windowBinding(
                    GodotWindowBindingEvent(
                        state: .nativeSurfaceUnsupported,
                        nodeName: node,
                        instanceId: windowInstanceId(window),
                        ownsWindow: ownsWindow,
                        platform: "ios"
                    )
                )
            )
            didLogMissingSetNativeSurface = true
        }

        subwindow = window
        ownsSubwindow = ownsWindow
        boundWindowInstanceId = windowInstanceId(window)
        inited = true
        didLogMissingNamedWindow = false

        if let callback {
            callback(window)
        }
        app?.emitRuntimeEvent(
            .windowBinding(
                GodotWindowBindingEvent(
                    state: state,
                    nodeName: node,
                    instanceId: boundWindowInstanceId,
                    ownsWindow: ownsWindow,
                    platform: "ios"
                )
            )
        )
        return true
    }

    private func clearBinding(removeOwnedWindow: Bool) {
        let detachedInstanceId = boundWindowInstanceId
        let detachedOwnsWindow = ownsSubwindow
        let hadBinding = inited || detachedInstanceId != nil
        if removeOwnedWindow, ownsSubwindow, let subwindow, isBoundWindowAlive() {
            subwindow.getParent()?.removeChild(node: subwindow)
        }
        inited = false
        subwindow = nil
        boundWindowInstanceId = nil
        ownsSubwindow = false
        if hadBinding {
            app?.emitRuntimeEvent(
                .windowBinding(
                    GodotWindowBindingEvent(
                        state: .detached,
                        nodeName: node,
                        instanceId: detachedInstanceId,
                        ownsWindow: detachedOwnsWindow,
                        platform: "ios"
                    )
                )
            )
        }
    }

    private func windowInstanceId(_ window: Window) -> Int64 {
        Int64(bitPattern: UInt64(window.getInstanceId()))
    }

    private func isBoundWindowAlive() -> Bool {
        guard let boundWindowInstanceId else { return false }
        return GD.isInstanceIdValid(id: boundWindowInstanceId)
    }
}
#endif
