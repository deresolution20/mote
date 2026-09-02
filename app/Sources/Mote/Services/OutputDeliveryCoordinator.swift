import Foundation
import MoteCleanup

enum TextDeliveryResult: Equatable {
    case typedAttempted(TargetApplication?)
    case copiedNoFocusedTarget(TargetApplication?)
    case copiedByUser
    case notInserted

    var insertionOutcome: InsertionOutcome {
        switch self {
        case .typedAttempted: .typedAttempted
        case .copiedNoFocusedTarget: .copiedNoFocusedTarget
        case .copiedByUser: .copiedByUser
        case .notInserted: .notInserted
        }
    }
}

@MainActor
protocol TextDelivering {
    func deliver(_ text: String, method: TextInjector.Method, target: TargetApplication?) -> TextDeliveryResult
    func copy(_ text: String) -> TextDeliveryResult
}

@MainActor
struct SystemTextDeliverer: TextDelivering {
    func deliver(_ text: String, method: TextInjector.Method, target: TargetApplication?) -> TextDeliveryResult {
        guard !text.isEmpty else { return .notInserted }
        guard let target else {
            TextInjector.copy(text)
            return .copiedNoFocusedTarget(nil)
        }
        TextInjector.insert(text, method: method)
        return .typedAttempted(target)
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

@MainActor
struct OutputDeliveryCoordinator {
    private let outputResolution: OutputResolution
    private let targetInspector: any FocusedTargetInspecting
    private let textDeliverer: any TextDelivering

    init(
        outputResolution: OutputResolution = OutputResolution(),
        targetInspector: (any FocusedTargetInspecting)? = nil,
        textDeliverer: (any TextDelivering)? = nil
    ) {
        self.outputResolution = outputResolution
        self.targetInspector = targetInspector ?? FocusedTargetInspector()
        self.textDeliverer = textDeliverer ?? SystemTextDeliverer()
    }

    func complete(
        raw: String,
        cleaned: String,
        format: OutputFormat,
        formattingOptions: FormattingOptions,
        autoInsert: Bool,
        method: TextInjector.Method,
        duration: TimeInterval
    ) async -> DictationCompletion {
        let resolved = await outputResolution.resolve(
            cleaned,
            requestedFormat: format,
            options: formattingOptions
        )
        let id = UUID()
        let pending = PendingDictation(
            id: id,
            rawText: raw,
            plainText: cleaned,
            resolved: resolved,
            duration: duration
        )

        let target = autoInsert ? targetInspector.focusedTarget() : nil
        let delivery: TextDeliveryResult
        if autoInsert, let target {
            // Focus can change while cleanup/formatting finishes. Re-check at
            // the injection boundary so automatic output is never directed at
            // a different application than the one we captured.
            if targetInspector.focusedTarget() == target {
                delivery = textDeliverer.deliver(
                    resolved.text,
                    method: method,
                    target: target.application
                )
            } else {
                delivery = .notInserted
            }
        } else if autoInsert {
            // Preserve the explicit clipboard fallback when no editable target
            // exists at capture time.
            delivery = textDeliverer.deliver(resolved.text, method: method, target: nil)
        } else {
            delivery = .notInserted
        }
        let record = DictationRecord(
            id: id,
            createdAt: .now,
            duration: duration,
            rawText: raw,
            finalText: resolved.text,
            format: resolved.effectiveFormat,
            targetApplication: target?.application,
            insertionOutcome: delivery.insertionOutcome
        )
        return DictationCompletion(
            pending: !autoInsert || delivery == .notInserted ? pending : nil,
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

    func insert(_ pending: PendingDictation, method: TextInjector.Method) -> TextDeliveryResult {
        insert(pending.resolved.text, method: method)
    }

    func copy(_ pending: PendingDictation) -> TextDeliveryResult {
        copy(pending.resolved.text)
    }

    func insert(_ text: String, method: TextInjector.Method) -> TextDeliveryResult {
        textDeliverer.deliver(
            text,
            method: method,
            target: targetInspector.focusedTarget()?.application
        )
    }

    func copy(_ text: String) -> TextDeliveryResult {
        textDeliverer.copy(text)
    }
}
