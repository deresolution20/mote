import Foundation
import MoteCleanup

enum TextDeliveryResult: Equatable {
    case insertedVerified(DeliveryMethod, TargetApplication)
    case insertedUnverified(DeliveryMethod, TargetApplication)
    case blocked(DeliveryBlockReason, TargetApplication?)
    case copiedByUser
    case notInserted

    var insertionOutcome: InsertionOutcome {
        switch self {
        case .insertedVerified: .insertedVerified
        case .insertedUnverified: .insertedUnverified
        case .blocked(let reason, _):
            switch reason {
            case .focusChanged: .blockedFocusChanged
            case .secureField: .blockedSecureField
            case .noEditableTarget: .blockedNoTarget
            case .deliveryUnavailable: .blockedDeliveryUnavailable
            }
        case .copiedByUser: .copiedByUser
        case .notInserted: .notInserted
        }
    }

    var pendingReason: PendingDeliveryReason? {
        switch self {
        case .insertedVerified, .copiedByUser: nil
        case .insertedUnverified(let method, _): .unverified(method)
        case .blocked(let reason, _): .blocked(reason)
        case .notInserted: .manual
        }
    }
}

@MainActor
protocol TextDelivering: AnyObject {
    func deliver(
        _ text: String,
        method: DeliveryMethod,
        target: FocusedTarget
    ) async -> DeliveryAttempt
    func copy(_ text: String) -> TextDeliveryResult
}

@MainActor
final class SystemTextDeliverer: TextDelivering {
    private let injector: any TextInjecting

    init(injector: (any TextInjecting)? = nil) {
        self.injector = injector ?? SystemTextInjector()
    }

    func deliver(
        _ text: String,
        method: DeliveryMethod,
        target: FocusedTarget
    ) async -> DeliveryAttempt {
        await injector.insert(text, method: method, target: target)
    }

    func copy(_ text: String) -> TextDeliveryResult {
        guard !text.isEmpty else { return .notInserted }
        TextInjector.copy(text)
        return .copiedByUser
    }
}

struct DictationCompletion: Equatable {
    let pending: PendingDictation?
    let record: DictationRecord
    let delivery: TextDeliveryResult
}

struct TargetCapture {
    let initialSnapshot: FocusSnapshot
    let focusMonitor: (any FocusChangeMonitoring)?

    var application: TargetApplication? { initialSnapshot.context?.application }
    var target: FocusedTarget? { initialSnapshot.target }

    init(
        initialSnapshot: FocusSnapshot,
        focusMonitor: (any FocusChangeMonitoring)?
    ) {
        self.initialSnapshot = initialSnapshot
        self.focusMonitor = focusMonitor
    }

}

@MainActor
struct OutputDeliveryCoordinator {
    private let outputResolution: OutputResolution
    private let targetInspector: any FocusedTargetInspecting
    private let textDeliverer: any TextDelivering
    private let verifiedDeliveryStore: VerifiedDeliveryStore
    private let focusMonitorFactory: (pid_t) -> (any FocusChangeMonitoring)?

    init(
        outputResolution: OutputResolution = OutputResolution(),
        targetInspector: (any FocusedTargetInspecting)? = nil,
        textDeliverer: (any TextDelivering)? = nil,
        verifiedDeliveryStore: VerifiedDeliveryStore? = nil,
        focusMonitorFactory: @escaping (pid_t) -> (any FocusChangeMonitoring)? = {
            FocusChangeMonitor(processIdentifier: $0)
        }
    ) {
        self.outputResolution = outputResolution
        self.targetInspector = targetInspector ?? FocusedTargetInspector()
        self.textDeliverer = textDeliverer ?? SystemTextDeliverer()
        self.verifiedDeliveryStore = verifiedDeliveryStore ?? .shared
        self.focusMonitorFactory = focusMonitorFactory
    }

    func complete(
        raw: String,
        cleaned: String,
        format: OutputFormat,
        formattingOptions: FormattingOptions,
        autoInsert: Bool,
        targetCapture: TargetCapture?,
        deliveryMode: DeliveryMode,
        duration: TimeInterval
    ) async -> DictationCompletion {
        let resolved = await outputResolution.resolve(
            cleaned,
            requestedFormat: format,
            options: formattingOptions
        )
        let id = UUID()
        var pending = PendingDictation(
            id: id,
            rawText: raw,
            plainText: cleaned,
            resolved: resolved,
            duration: duration
        )

        let delivery: TextDeliveryResult
        if autoInsert, let targetCapture {
            let current = targetInspector.snapshot()
            if let target = Self.validatedTarget(capture: targetCapture, current: current) {
                delivery = await deliver(resolved.text, to: target, mode: deliveryMode)
            } else {
                let reason = Self.blockReason(capture: targetCapture, current: current)
                delivery = .blocked(reason, targetCapture.application)
            }
        } else if autoInsert {
            delivery = .blocked(.noEditableTarget, nil)
        } else {
            delivery = .notInserted
        }

        switch delivery {
        case .blocked(let reason, _):
            pending = pending.replacingDeliveryReason(.blocked(reason))
        case .insertedUnverified(let method, _):
            pending = pending.replacingDeliveryReason(.unverified(method))
        case .insertedVerified, .copiedByUser:
            break
        case .notInserted:
            pending = pending.replacingDeliveryReason(.manual)
        }

        let record = DictationRecord(
            id: id,
            createdAt: .now,
            duration: duration,
            rawText: raw,
            finalText: resolved.text,
            format: resolved.effectiveFormat,
            targetApplication: targetCapture?.application,
            insertionOutcome: delivery.insertionOutcome
        )
        return DictationCompletion(
            pending: delivery.pendingReason == nil ? nil : pending,
            record: record,
            delivery: delivery
        )
    }

    func resolve(
        _ pending: PendingDictation,
        format: OutputFormat,
        options: FormattingOptions
    ) async -> PendingDictation {
        let resolved = await outputResolution.resolve(
            pending.plainText,
            requestedFormat: format,
            options: options
        )
        return pending.replacingResolved(resolved)
    }

    func beginTargetCapture() -> TargetCapture {
        let snapshot = targetInspector.snapshot()
        let monitor = snapshot.context.flatMap { context in
            focusMonitorFactory(context.processIdentifier)
        }
        return TargetCapture(initialSnapshot: snapshot, focusMonitor: monitor)
    }

    static func validatedTarget(
        capture: TargetCapture,
        current: FocusSnapshot
    ) -> FocusedTarget? {
        guard capture.focusMonitor?.invalidated != true else { return nil }
        guard capture.focusMonitor != nil else { return nil }

        let original = capture.initialSnapshot
        if let originalTarget = original.target, current.target == originalTarget {
            return current.target
        }
        guard let originalContext = original.context, let currentContext = current.context else {
            return nil
        }

        guard capture.focusMonitor != nil, originalContext.isSameWindow(as: currentContext) else {
            return nil
        }
        if original.target == nil { return current.target }
        return current.target == nil ? original.target : nil
    }

    func insert(
        _ pending: PendingDictation,
        deliveryMode: DeliveryMode
    ) async -> TextDeliveryResult {
        await insert(pending.resolved.text, deliveryMode: deliveryMode)
    }

    func insert(
        _ text: String,
        deliveryMode: DeliveryMode
    ) async -> TextDeliveryResult {
        guard !text.isEmpty else { return .notInserted }
        let capture = beginTargetCapture()
        let current = targetInspector.snapshot()
        guard let target = Self.validatedTarget(capture: capture, current: current) else {
            return .blocked(Self.blockReason(capture: capture, current: current), capture.application)
        }
        return await deliver(text, to: target, mode: deliveryMode)
    }

    func copy(_ pending: PendingDictation) -> TextDeliveryResult {
        copy(pending.resolved.text)
    }

    func copy(_ text: String) -> TextDeliveryResult {
        textDeliverer.copy(text)
    }

    private func deliver(
        _ text: String,
        to target: FocusedTarget,
        mode: DeliveryMode
    ) async -> TextDeliveryResult {
        guard target.capabilities.isEligible else {
            return .blocked(
                target.capabilities.isSecure ? .secureField : .noEditableTarget,
                target.application
            )
        }

        if target.capabilities.canVerifySelectedTextReplacement {
            let attempt = await textDeliverer.deliver(
                text,
                method: .accessibility,
                target: target
            )
            if case .unavailable(.accessibility) = attempt {
                // The adapter proved it could not attempt a mutation, so one
                // different delivery mechanism may be tried safely.
            } else {
                return result(for: attempt, target: target)
            }
        }

        let surfaceKey = target.deliverySurfaceKey()
        let preferred = surfaceKey.flatMap(verifiedDeliveryStore.preferredMethod)
        let fallback = TextDeliveryPolicy.fallbackMethod(
            mode: mode,
            preferredVerifiedMethod: preferred
        )
        let attempt = await textDeliverer.deliver(text, method: fallback, target: target)
        if case .verified(let method) = attempt, let surfaceKey {
            verifiedDeliveryStore.recordVerified(method, for: surfaceKey)
        }
        return result(for: attempt, target: target)
    }

    private func result(
        for attempt: DeliveryAttempt,
        target: FocusedTarget
    ) -> TextDeliveryResult {
        switch attempt {
        case .verified(let method):
            .insertedVerified(method, target.application)
        case .unverified(let method):
            .insertedUnverified(method, target.application)
        case .unavailable:
            .blocked(.deliveryUnavailable, target.application)
        }
    }

    private static func blockReason(
        capture: TargetCapture,
        current: FocusSnapshot
    ) -> DeliveryBlockReason {
        if capture.focusMonitor?.invalidated == true { return .focusChanged }
        guard let originalContext = capture.initialSnapshot.context else {
            return .noEditableTarget
        }
        guard capture.focusMonitor != nil else { return .deliveryUnavailable }
        guard let currentContext = current.context else { return .focusChanged }
        if capture.initialSnapshot.target == nil,
           current.target == nil,
           originalContext == currentContext {
            return .noEditableTarget
        }
        return .focusChanged
    }
}
