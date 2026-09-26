import Foundation
import SwiftGodot
@_implementationOnly import GDExtension

final class SwiftGodotHostBridge: Node {
    static let nodeName = "__swiftgodotkit_bridge__"

    var onMessageToHost: ((VariantDictionary) -> Void)?
    private var lastHostViewId: Int64?

    public func emitMessageToHost(message: VariantDictionary) {
        let payload = VariantDictionary(from: message)
        if !payload.has(key: Variant(BridgeRouting.viewIdKey)), let lastHostViewId {
            payload[BridgeRouting.viewIdKey] = Variant(lastHostViewId)
        }
        onMessageToHost?(payload)
    }

    public func receiveMessageFromHost(message: VariantDictionary) {
        lastHostViewId = BridgeRouting.routedViewId(from: message)
        _ = emitSignal("messageFromHost", Variant(message))
    }

    override public class var classInitializer: Void {
        let _ = super.classInitializer
        return initializeClass
    }

    private static let initializeClass: Void = {
        let classInfo = ClassInfo<SwiftGodotHostBridge>(name: "SwiftGodotHostBridge")
        let messageArgument = PropInfo(
            propertyType: .dictionary,
            propertyName: "message",
            className: "",
            hint: .none,
            hintStr: "",
            usage: .default
        )
        classInfo.registerSignal(name: "messageFromHost", arguments: [messageArgument])
        classInfo.registerMethod(
            name: "emitMessageToHost",
            flags: .default,
            returnValue: nil,
            arguments: [messageArgument],
            function: SwiftGodotHostBridge.emitMessageToHostFromGodot
        )
    }()

    private func emitMessageToHostFromGodot(args: borrowing Arguments) -> Variant? {
        guard let first = args.first,
              let value = first,
              let message = VariantDictionary(value)
        else {
            return nil
        }
        emitMessageToHost(message: message)
        return nil
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
