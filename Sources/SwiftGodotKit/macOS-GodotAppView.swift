//
//  MacOS/GodotAppView.swift
//
//

import SwiftUI
import SwiftGodot
#if os(macOS)
public struct GodotAppView: NSViewRepresentable {
    @EnvironmentObject var sceneHost: GodotSceneHost
    var view = NSGodotAppView(frame: CGRect.zero)
    
    public init () {
        
    }
    public func makeNSView(context: Context) -> NSGodotAppView {
        sceneHost.start()
        view.sceneHost = sceneHost
        return view
    }

    public func updateNSView(_ nsView: NSGodotAppView, context: Context) {
        nsView.startGodotInstance()
    }
}

public class NSGodotAppView: NSView {
    public var renderingLayer: CAMetalLayer? = nil
    private var link : CADisplayLink? = nil
    private var embedded: DisplayServerEmbedded?
    
    public var sceneHost: GodotSceneHost?

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
        guard DisplayServer.mainWindowId != 0 else {
            print ("Can not resize yet")
            return
        }
        
        embedded.resizeWindow(
            size: Vector2i(x: Int32(self.bounds.size.width), y: Int32(self.bounds.size.height)),
            id: Int32(DisplayServer.mainWindowId)
        )
    }
    
    public override func layout() {
        if let renderingLayer {
            renderingLayer.frame = self.bounds
        }
        if let instance = sceneHost?.instance {
            if instance.isStarted() {
                if embedded == nil {
                    embedded = DisplayServerEmbedded(nativeHandle: DisplayServer.shared.handle)
                }
                
                resizeWindow()
            }
        }
        super.layout()
    }
    
    func startGodotInstance() {
        if let instance = sceneHost?.instance {
            if !instance.isStarted() {
                let rendererNativeSurface = RenderingNativeSurfaceApple.create(layer: UInt(bitPattern: Unmanaged.passUnretained(renderingLayer!).toOpaque()))
                DisplayServerEmbedded.setNativeSurface(rendererNativeSurface)
                _ = instance.start()
                let link = displayLink(target: self, selector: #selector(iterate))
                link.add(to: .current, forMode: RunLoop.Mode.default)
                self.link = link
            }
        }
    }
    
    public override func removeFromSuperview() {
        link?.invalidate()
        link = nil
        
        if let instance = sceneHost?.instance {
            GodotInstance.destroy(instance: instance)
        }
    }
    
    public override func viewDidMoveToSuperview() {
        commonInit()
        startGodotInstance()
    }
    
    @objc
    func iterate() {
        if let instance = sceneHost?.instance {
            if instance.isStarted() {
                _ = instance.iteration()
            }
        }
    }
}
#endif
