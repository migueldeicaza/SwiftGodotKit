import Foundation

/// Owns the synchronous startup transitions. Calls into Godot can re-enter
/// Swift code, so every transition precedes the call that can re-enter.
final class StartupCoordinator<Instance: AnyObject> {
    enum Phase {
        case idle
        case creating
        case initialized(Instance)
        case preparing(Instance)
        case starting(Instance)
        case running(Instance)
        case stopping(Instance)
        case failed(Instance?)
    }

    enum CreationDecision {
        case create
        case alreadyCreated
        case inProgress
        case failed
    }

    enum ViewDecision {
        case prepare(Instance)
        case running(Instance)
        case wait
        case failed
    }

    enum StopDecision {
        case destroy(Instance)
        case deferUntilReady
        case needsEngineStart
        case alreadyStopped
        case failed
    }

    private(set) var phase: Phase = .idle {
        didSet { onPhaseChange?() }
    }
    var onPhaseChange: (() -> Void)?

    var instance: Instance? {
        switch phase {
        case .initialized(let instance), .preparing(let instance),
             .starting(let instance), .running(let instance),
             .stopping(let instance):
            return instance
        case .failed(let instance):
            return instance
        case .idle, .creating:
            return nil
        }
    }

    var isRunning: Bool {
        if case .running = phase { return true }
        return false
    }

    var isIdle: Bool {
        if case .idle = phase { return true }
        return false
    }

    var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    func beginCreation() -> CreationDecision {
        switch phase {
        case .idle:
            phase = .creating
            return .create
        case .initialized, .running:
            return .alreadyCreated
        case .creating, .preparing, .starting, .stopping:
            return .inProgress
        case .failed:
            return .failed
        }
    }

    func cancelCreation() {
        guard case .creating = phase else { return }
        phase = .idle
    }

    func completeCreation(_ instance: Instance?) {
        guard case .creating = phase else { return }
        if let instance {
            phase = .initialized(instance)
        } else {
            phase = .failed(nil)
        }
    }

    func beginViewStartup() -> ViewDecision {
        switch phase {
        case .initialized(let instance):
            phase = .preparing(instance)
            return .prepare(instance)
        case .running(let instance):
            return .running(instance)
        case .idle, .creating, .preparing, .starting, .stopping:
            return .wait
        case .failed:
            return .failed
        }
    }

    func finishSurfacePreparation(succeeded: Bool) -> Instance? {
        guard case .preparing(let instance) = phase else { return nil }
        phase = succeeded ? .starting(instance) : .initialized(instance)
        return succeeded ? instance : nil
    }

    func finishEngineStart(succeeded: Bool) {
        guard case .starting(let instance) = phase else { return }
        phase = succeeded ? .running(instance) : .failed(instance)
    }

    func beginStop() -> StopDecision {
        switch phase {
        case .running(let instance):
            phase = .stopping(instance)
            return .destroy(instance)
        case .initialized:
            return .needsEngineStart
        case .creating, .preparing, .starting, .stopping:
            return .deferUntilReady
        case .idle:
            return .alreadyStopped
        case .failed:
            return .failed
        }
    }

    func finishStop() {
        guard case .stopping = phase else { return }
        phase = .idle
    }
}

/// Removes a batch before callbacks run. A callback can queue work for the
/// next drain without losing it to a trailing removeAll().
final class SnapshotQueue<Element: Hashable> {
    private var items = Set<Element>()

    var isEmpty: Bool { items.isEmpty }

    func insert(_ item: Element) { items.insert(item) }
    func remove(_ item: Element) { items.remove(item) }
    func removeAll() { items.removeAll() }

    func drain(_ callback: (Element) -> Void) {
        let batch = items
        items.removeAll()
        for item in batch { callback(item) }
    }
}
