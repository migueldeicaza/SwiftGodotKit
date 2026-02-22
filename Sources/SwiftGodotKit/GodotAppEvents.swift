import Foundation

public enum GodotAppEvent {
    case startupFailure(GodotStartupFailureEvent)
    case warning(GodotWarningEvent)
    case bridge(GodotBridgeEvent)
    case windowBinding(GodotWindowBindingEvent)
    case lifecycle(GodotLifecycleEvent)
}

public struct GodotStartupFailureEvent {
    public enum Reason: String {
        case sourcePathMissing
        case projectFileMissing
        case sceneMissing
        case instanceCreationFailed
    }

    public let reason: Reason
    public let sourcePath: String
    public let scene: String?

    public init(reason: Reason, sourcePath: String, scene: String? = nil) {
        self.reason = reason
        self.sourcePath = sourcePath
        self.scene = scene
    }
}

public struct GodotWarningEvent {
    public enum Code: String {
        case globalScriptCacheMissing
        case limitedSceneValidation
        case skippedSceneValidationUri
        case runOnGodotThreadBeforeInstance
        case windowNativeSurfaceUnsupported
        case displayServerNotEmbedded
    }

    public let code: Code
    public let detail: String

    public init(code: Code, detail: String) {
        self.code = code
        self.detail = detail
    }
}

public struct GodotBridgeEvent {
    public enum State: String {
        case attachedExisting
        case attachedCreated
        case detached
    }

    public let state: State

    public init(state: State) {
        self.state = state
    }
}

public struct GodotWindowBindingEvent {
    public enum State: String {
        case missingNamedWindow
        case bound
        case rebound
        case detached
        case nativeSurfaceUnsupported
    }

    public let state: State
    public let nodeName: String?
    public let instanceId: Int64?
    public let ownsWindow: Bool
    public let platform: String

    public init(
        state: State,
        nodeName: String?,
        instanceId: Int64?,
        ownsWindow: Bool,
        platform: String
    ) {
        self.state = state
        self.nodeName = nodeName
        self.instanceId = instanceId
        self.ownsWindow = ownsWindow
        self.platform = platform
    }
}

public struct GodotLifecycleEvent {
    public let label: String
    public let notification: Int32

    public init(label: String, notification: Int32) {
        self.label = label
        self.notification = notification
    }
}
