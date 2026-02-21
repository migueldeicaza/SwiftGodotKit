//
//  MacOS/GodotAppView.swift
//
//

import OSLog
import SwiftUI
import SwiftGodot
#if os(macOS)
public struct GodotAppView: NSViewRepresentable {
    @SwiftUI.Environment(\.godotApp) var app: GodotApp?
    var view = NSGodotAppView(frame: CGRect.zero)
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

    public func makeNSView(context: Context) -> NSGodotAppView {
        guard let app else {
            Logger.App.error("No GodotApp instance, you must pass it on the environment using \\.godotApp")
            return view
        }
        app.configureLaunch(source: source, scene: scene)
        view.app = app
        view.source = source
        view.scene = scene
        view.onReady = onReady
        view.onMessage = onMessage
        view.syncCallbackRegistration()
        return view
    }

    public func updateNSView(_ nsView: NSGodotAppView, context: Context) {
        app?.configureLaunch(source: source, scene: scene)
        nsView.source = source
        nsView.scene = scene
        nsView.onReady = onReady
        nsView.onMessage = onMessage
        nsView.syncCallbackRegistration()
        nsView.startGodotInstance()
    }
}

typealias TTGodotAppView = NSGodotAppView
typealias TTGodotWindow = NSGodotWindow

public class NSGodotAppView: GodotView {
    private var link : CADisplayLink? = nil
    private var frameTimer: Foundation.Timer? = nil
    private var frameCount: UInt64 = 0
    private var loggedSurfaceBinding = false
    private var didEmitDisplayServerNotEmbeddedWarning = false
    private var callbackToken: UUID?
    private weak var callbackApp: GodotApp?

    private func stderrLog(_ message: String) {
        if let data = ("[SwiftGodotKit] " + message + "\n").data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }

    private func emitDisplayServerNotEmbeddedWarning(context: String) {
        guard !didEmitDisplayServerNotEmbeddedWarning else { return }
        didEmitDisplayServerNotEmbeddedWarning = true
        let detail = "DisplayServer.shared is not DisplayServerEmbedded (\(context))"
        logger.error("\(detail, privacy: .public)")
        print("[SwiftGodotKit] \(detail)")
        stderrLog(detail)
        app?.emitRuntimeEvent(
            .warning(
                GodotWarningEvent(
                    code: .displayServerNotEmbedded,
                    detail: detail
                )
            )
        )
    }
    
    public var app: GodotApp?
    public var source: String?
    public var scene: String?
    public var onReady: ((GodotAppViewHandle) -> Void)?
    public var onMessage: ((VariantDictionary) -> Void)?
    
    public override func layout() {
        if let renderingLayer {
            renderingLayer.frame = self.bounds
        }
        
        if let app, let instance = app.instance {
            if instance.isStarted() {
                if app.displayDriver == "embedded" {
                    if embedded == nil {
                        if let displayServer = DisplayServer.shared as? DisplayServerEmbedded {
                            embedded = displayServer
                            logger.info("NSGodotAppView.layout created embedded display server")
                            print("[SwiftGodotKit] NSGodotAppView.layout created embedded display server")
                        } else {
                            emitDisplayServerNotEmbeddedWarning(context: "layout")
                        }
                    }

                    resizeWindow()
                }
            }
        } else if let app {
            app.queueLayout(self)
        }
        super.layout()
    }

    func startGodotInstance() {
        syncCallbackRegistration()
        if let app, let instance = app.instance {
            if app.displayDriver == "embedded" {
                guard let renderingLayer else {
                    Logger.App.error("startGodotInstance: renderingLayer was nil")
                    return
                }
                let rendererNativeSurface = RenderingNativeSurfaceApple.create(layer: UInt(bitPattern: Unmanaged.passUnretained(renderingLayer).toOpaque()))
                DisplayServerEmbedded.setNativeSurface(rendererNativeSurface)
                if !loggedSurfaceBinding {
                    logger.info("Bound native surface layer=\(String(describing: renderingLayer), privacy: .public) size=\(String(describing: renderingLayer.drawableSize), privacy: .public)")
                    print("[SwiftGodotKit] Bound native surface size=\(renderingLayer.drawableSize)")
                    loggedSurfaceBinding = true
                }
            }
            print("[SwiftGodotKit] startGodotInstance before instance.isStarted()")
            let alreadyStarted = instance.isStarted()
            print("[SwiftGodotKit] startGodotInstance after instance.isStarted() -> \(alreadyStarted)")
            if !alreadyStarted {
                let started = instance.start()
                Logger.App.info("startGodotInstance: instance.start() -> \(started)")
                print("[SwiftGodotKit] startGodotInstance instance.start() -> \(started)")
                stderrLog("startGodotInstance instance.start() -> \(started)")
            }
            if app.displayDriver == "embedded", embedded == nil {
                if let displayServer = DisplayServer.shared as? DisplayServerEmbedded {
                    embedded = displayServer
                    print("[SwiftGodotKit] startGodotInstance created embedded display server")
                    stderrLog("startGodotInstance created embedded display server")
                } else {
                    emitDisplayServerNotEmbeddedWarning(context: "startGodotInstance")
                }
            }
            resizeWindow()
            app.pollBridgeAndReadiness()
            if link == nil {
                let link = displayLink(target: self, selector: #selector(iterate(_:)))
                link.add(to: .main, forMode: RunLoop.Mode.common)
                self.link = link
                print("[SwiftGodotKit] CADisplayLink installed")
                stderrLog("CADisplayLink installed")
            }
            if frameTimer == nil {
                let timer = Foundation.Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                    self?.iterateFrame()
                }
                RunLoop.main.add(timer, forMode: .common)
                frameTimer = timer
                print("[SwiftGodotKit] Frame timer installed")
                stderrLog("Frame timer installed")
            }
        } else if let app {
            app.queueStart(self)
        }
    }
    
    public override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if superview == nil {
            link?.invalidate()
            link = nil
            frameTimer?.invalidate()
            frameTimer = nil
            frameCount = 0
            unregisterCallbacks()
        }
    }
    public override func viewDidMoveToWindow() {
        // It seems doing this in viewDidMoveToSuperview is too early to start the Godot app.
        if window != nil {
            app?.start()
            startGodotInstance()
            needsLayout = true
        }
    }
    
    @objc
    func iterate(_ link: CADisplayLink) {
        iterateFrame()
    }

    private func iterateFrame() {
        if let app, (app.isPaused || !app.isDrawing) {
            return
        }
        if let instance = app?.instance, instance.isStarted() {
            _ = instance.iteration()
            app?.pollBridgeAndReadiness()
            frameCount += 1
            if frameCount == 1 || frameCount % 300 == 0 {
                logger.info("NSGodotAppView.iterate frame=\(self.frameCount)")
                print("[SwiftGodotKit] iterate frame=\(frameCount)")
                stderrLog("iterate frame=\(frameCount)")
            }
        }
    }

    deinit {
        unregisterCallbacks()
    }
}

private extension NSGodotAppView {
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
