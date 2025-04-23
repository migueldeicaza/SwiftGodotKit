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

    public init () {
    }

    public func makeNSView(context: Context) -> NSGodotAppView {
        guard let app else {
            Logger.App.error("No GodotApp instance, you must pass it on the environment using \\.godotApp")
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

public class NSGodotAppView: GodotView {
    private var link : CADisplayLink? = nil
    
    public var app: GodotApp?
    
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
            }
        } else if let app {
            app.queueStart(self)
        }
    }
    
    public override func viewDidMoveToSuperview() {
        if superview != nil {
            link?.invalidate()
            link = nil
            
            if let instance = app?.instance {
                GodotInstance.destroy(instance: instance)
            }
        }
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
}

private extension NSGodotAppView {
}
#endif
