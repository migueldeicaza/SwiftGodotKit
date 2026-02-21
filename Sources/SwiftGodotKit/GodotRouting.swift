import SwiftGodot

enum BridgeRouting {
    static let viewIdKey = "__swiftgodotkit_view_id"

    static func routedViewId(from message: VariantDictionary) -> Int64? {
        if let value = Int64(message[viewIdKey]) {
            return value
        }
        if let text = String(message[viewIdKey]), let value = Int64(text) {
            return value
        }
        return nil
    }
}
