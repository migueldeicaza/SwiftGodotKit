import Foundation
import SwiftGodot
@_implementationOnly import GDExtension

@Godot
final class SwiftGodotHostBridge: Node {
    static let nodeName = "__swiftgodotkit_bridge__"

    @Signal var messageFromHost: SignalWithArguments<VariantDictionary>
    var onMessageToHost: ((VariantDictionary) -> Void)?
    private var lastHostViewId: Int64?

    @Callable
    public func emitMessageToHost(message: VariantDictionary) {
        let payload = VariantDictionary(from: message)
        if !payload.has(key: Variant(BridgeRouting.viewIdKey)), let lastHostViewId {
            payload[BridgeRouting.viewIdKey] = Variant(lastHostViewId)
        }
        onMessageToHost?(payload)
    }

    public func receiveMessageFromHost(message: VariantDictionary) {
        lastHostViewId = BridgeRouting.routedViewId(from: message)
        messageFromHost.emit(message)
    }
}

private let hostBridgeRegistrationLock = NSLock()
private var didInstallHostBridgeHook = false

func ensureHostBridgeTypeRegistration() {
    hostBridgeRegistrationLock.lock()
    defer { hostBridgeRegistrationLock.unlock() }
    guard !didInstallHostBridgeHook else { return }
    didInstallHostBridgeHook = true

    let previous = initHookCb
    initHookCb = { level in
        previous?(level)
        if level == .scene {
            register(type: SwiftGodotHostBridge.self)
        }
    }
}
