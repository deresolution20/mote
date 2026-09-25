import ApplicationServices
import Foundation
import MoteCleanup
import Testing
@testable import Mote

@MainActor
@Suite struct OutputDeliveryCoordinatorTests {
    @Test func secureTargetIsBlockedWithoutCallingTheDeliveryAdapter() async {
        let context = FocusContext.fixture(windowToken: 7)
        let target = FocusedTarget.secureFixture(context: context, token: 10)
        let deliverer = SequenceAttemptDeliverer(results: [])
        let coordinator = makeCoordinator(
            targetInspector: SnapshotTargetInspector([
                FocusSnapshot(context: context, target: target),
            ]),
            deliverer: deliverer
        )

        let result = await coordinator.complete(
            raw: "secret",
            cleaned: "secret",
            format: .plain,
            formattingOptions: .init(preserveCodeAndBackticks: false),
            autoInsert: true,
            targetCapture: capture(context: context, target: target),
            deliveryMode: .automatic,
            duration: 0.5
        )

        #expect(result.delivery == .blocked(.secureField, .fixture))
        #expect(result.pending?.deliveryReason == .blocked(.secureField))
        #expect(deliverer.methods.isEmpty)
        #expect(result.record.insertionOutcome == .blockedSecureField)
    }

    @Test func unavailableAccessibilityWriteFallsBackExactlyOnce() async {
        let context = FocusContext.fixture(windowToken: 7)
        let target = FocusedTarget.verifiableFixture(context: context, token: 10)
        let deliverer = SequenceAttemptDeliverer(results: [
            .unavailable(.accessibility),
            .verified(.clipboard),
        ])
        let coordinator = makeCoordinator(
            targetInspector: SnapshotTargetInspector([
                FocusSnapshot(context: context, target: target),
            ]),
            deliverer: deliverer
        )

        let result = await coordinator.complete(
            raw: "hello",
            cleaned: "Hello",
            format: .plain,
            formattingOptions: .init(preserveCodeAndBackticks: false),
            autoInsert: true,
            targetCapture: capture(context: context, target: target),
            deliveryMode: .automatic,
            duration: 0.5
        )

        #expect(result.delivery == .insertedVerified(.clipboard, .fixture))
        #expect(result.pending == nil)
        #expect(deliverer.methods == [.accessibility, .clipboard])
        #expect(result.record.insertionOutcome == .insertedVerified)
    }

    @Test func unverifiedAttemptIsPreservedAndNeverRetried() async {
        let context = FocusContext.fixture(windowToken: 7)
        let target = FocusedTarget.fixture(context: context, token: 10)
        let deliverer = SequenceAttemptDeliverer(results: [.unverified(.directEvents)])
        let coordinator = makeCoordinator(
            targetInspector: SnapshotTargetInspector([
                FocusSnapshot(context: context, target: target),
            ]),
            deliverer: deliverer
        )

        let result = await coordinator.complete(
            raw: "hello",
            cleaned: "Hello",
            format: .plain,
            formattingOptions: .init(preserveCodeAndBackticks: false),
            autoInsert: true,
            targetCapture: capture(context: context, target: target),
            deliveryMode: .privacyFirst,
            duration: 0.5
        )

        #expect(result.delivery == .insertedUnverified(.directEvents, .fixture))
        #expect(result.pending?.deliveryReason == .unverified(.directEvents))
        #expect(deliverer.methods == [.directEvents])
        #expect(result.record.insertionOutcome == .insertedUnverified)
    }

    @Test func unverifiedAccessibilityMutationNeverFallsBack() async {
        let context = FocusContext.fixture(windowToken: 7)
        let target = FocusedTarget.verifiableFixture(context: context, token: 10)
        let deliverer = SequenceAttemptDeliverer(results: [
            .unverified(.accessibility),
            .verified(.clipboard),
        ])
        let coordinator = makeCoordinator(
            targetInspector: SnapshotTargetInspector([
                FocusSnapshot(context: context, target: target),
            ]),
            deliverer: deliverer
        )

        let result = await coordinator.complete(
            raw: "hello",
            cleaned: "Hello",
            format: .plain,
            formattingOptions: .init(preserveCodeAndBackticks: false),
            autoInsert: true,
            targetCapture: capture(context: context, target: target),
            deliveryMode: .automatic,
            duration: 0.5
        )

        #expect(result.delivery == .insertedUnverified(.accessibility, .fixture))
        #expect(result.pending?.deliveryReason == .unverified(.accessibility))
        #expect(deliverer.methods == [.accessibility])
    }

    @Test func manualModeKeepsFormattedTextPending() async {
        let deliverer = SequenceAttemptDeliverer(results: [])
        let coordinator = OutputDeliveryCoordinator(
            outputResolution: .init(
                formatter: .init(provider: StaticProvider(output: "- [ ] Confirm the panel loads"))
            ),
            targetInspector: SnapshotTargetInspector([]),
            textDeliverer: deliverer,
            verifiedDeliveryStore: makeStore()
        )

        let result = await coordinator.complete(
            raw: "confirm the panel loads",
            cleaned: "Confirm the panel loads",
            format: .markdown,
            formattingOptions: .init(preserveCodeAndBackticks: false),
            autoInsert: false,
            targetCapture: nil,
            deliveryMode: .automatic,
            duration: 0.8
        )

        #expect(result.pending?.resolved.text == "- [ ] Confirm the panel loads")
        #expect(result.pending?.deliveryReason == .manual)
        #expect(result.delivery == .notInserted)
        #expect(deliverer.methods.isEmpty)
    }

    @Test func missingCaptureBlocksWithoutCopyingOrTyping() async {
        let deliverer = SequenceAttemptDeliverer(results: [])
        let coordinator = makeCoordinator(
            targetInspector: SnapshotTargetInspector([]),
            deliverer: deliverer
        )

        let result = await coordinator.complete(
            raw: "hello",
            cleaned: "Hello",
            format: .plain,
            formattingOptions: .init(preserveCodeAndBackticks: false),
            autoInsert: true,
            targetCapture: nil,
            deliveryMode: .automatic,
            duration: 0.5
        )

        #expect(result.delivery == .blocked(.noEditableTarget, nil))
        #expect(result.pending?.deliveryReason == .blocked(.noEditableTarget))
        #expect(deliverer.methods.isEmpty)
    }

    @Test func focusNotificationInvalidatesCaptureBeforeDelivery() async {
        let context = FocusContext.fixture(windowToken: 7)
        let target = FocusedTarget.fixture(context: context, token: 10)
        let deliverer = SequenceAttemptDeliverer(results: [])
        let coordinator = makeCoordinator(
            targetInspector: SnapshotTargetInspector([
                FocusSnapshot(context: context, target: target),
            ]),
            deliverer: deliverer
        )
        let invalidated = TargetCapture(
            initialSnapshot: FocusSnapshot(context: context, target: target),
            focusMonitor: StubFocusMonitor(invalidated: true)
        )

        let result = await coordinator.complete(
            raw: "hello",
            cleaned: "Hello",
            format: .plain,
            formattingOptions: .init(preserveCodeAndBackticks: false),
            autoInsert: true,
            targetCapture: invalidated,
            deliveryMode: .automatic,
            duration: 0.5
        )

        #expect(result.delivery == .blocked(.focusChanged, .fixture))
        #expect(deliverer.methods.isEmpty)
    }

    @Test func missingFocusObserverFailsClosed() async {
        let context = FocusContext.fixture(windowToken: 7)
        let target = FocusedTarget.fixture(context: context, token: 10)
        let deliverer = SequenceAttemptDeliverer(results: [.verified(.directEvents)])
        let coordinator = makeCoordinator(
            targetInspector: SnapshotTargetInspector([
                FocusSnapshot(context: context, target: target),
            ]),
            deliverer: deliverer
        )
        let unobserved = TargetCapture(
            initialSnapshot: FocusSnapshot(context: context, target: target),
            focusMonitor: nil
        )

        let result = await coordinator.complete(
            raw: "hello",
            cleaned: "Hello",
            format: .plain,
            formattingOptions: .init(preserveCodeAndBackticks: false),
            autoInsert: true,
            targetCapture: unobserved,
            deliveryMode: .privacyFirst,
            duration: 0.5
        )

        #expect(result.delivery == .blocked(.deliveryUnavailable, .fixture))
        #expect(deliverer.methods.isEmpty)
    }

    @Test func aDifferentWindowCannotReceiveTheTranscript() async {
        let original = FocusContext.fixture(windowToken: 7)
        let changed = FocusContext.fixture(windowToken: 8)
        let originalTarget = FocusedTarget.fixture(context: original, token: 10)
        let changedTarget = FocusedTarget.fixture(context: changed, token: 11)
        let deliverer = SequenceAttemptDeliverer(results: [])
        let coordinator = makeCoordinator(
            targetInspector: SnapshotTargetInspector([
                FocusSnapshot(context: changed, target: changedTarget),
            ]),
            deliverer: deliverer
        )

        let result = await coordinator.complete(
            raw: "hello",
            cleaned: "Hello",
            format: .plain,
            formattingOptions: .init(preserveCodeAndBackticks: false),
            autoInsert: true,
            targetCapture: capture(context: original, target: originalTarget),
            deliveryMode: .automatic,
            duration: 0.5
        )

        #expect(result.delivery == .blocked(.focusChanged, .fixture))
        #expect(deliverer.methods.isEmpty)
    }

    @Test func temporarilyHiddenEditorCanUseOriginalObservedWindow() async {
        let context = FocusContext.fixture(windowToken: 7)
        let target = FocusedTarget.fixture(context: context, token: 10)
        let deliverer = SequenceAttemptDeliverer(results: [.verified(.directEvents)])
        let coordinator = makeCoordinator(
            targetInspector: SnapshotTargetInspector([
                FocusSnapshot(context: context, target: nil),
            ]),
            deliverer: deliverer
        )

        let result = await coordinator.complete(
            raw: "hello",
            cleaned: "Hello",
            format: .plain,
            formattingOptions: .init(preserveCodeAndBackticks: false),
            autoInsert: true,
            targetCapture: capture(context: context, target: target),
            deliveryMode: .privacyFirst,
            duration: 0.5
        )

        #expect(result.delivery == .insertedVerified(.directEvents, .fixture))
        #expect(deliverer.methods == [.directEvents])
    }

    @Test func manualRetryUsesTheCurrentValidatedTarget() async {
        let context = FocusContext.fixture(windowToken: 7)
        let target = FocusedTarget.fixture(context: context, token: 10)
        let snapshot = FocusSnapshot(context: context, target: target)
        let deliverer = SequenceAttemptDeliverer(results: [.verified(.directEvents)])
        let coordinator = OutputDeliveryCoordinator(
            targetInspector: SnapshotTargetInspector([snapshot, snapshot]),
            textDeliverer: deliverer,
            verifiedDeliveryStore: makeStore(),
            focusMonitorFactory: { _ in StubFocusMonitor(invalidated: false) }
        )

        let result = await coordinator.insert("Saved response", deliveryMode: .privacyFirst)

        #expect(result == .insertedVerified(.directEvents, .fixture))
        #expect(deliverer.methods == [.directEvents])
    }

    @Test func explicitCopyIsTheOnlyUnconditionalClipboardWrite() {
        let deliverer = SequenceAttemptDeliverer(results: [])
        let coordinator = makeCoordinator(
            targetInspector: SnapshotTargetInspector([]),
            deliverer: deliverer
        )

        #expect(coordinator.copy("Saved response") == .copiedByUser)
        #expect(deliverer.copiedTexts == ["Saved response"])
    }

    private func makeCoordinator(
        targetInspector: any FocusedTargetInspecting,
        deliverer: any TextDelivering
    ) -> OutputDeliveryCoordinator {
        OutputDeliveryCoordinator(
            outputResolution: .init(formatter: .init(provider: StaticProvider(output: nil))),
            targetInspector: targetInspector,
            textDeliverer: deliverer,
            verifiedDeliveryStore: makeStore()
        )
    }

    private func capture(
        context: FocusContext,
        target: FocusedTarget?
    ) -> TargetCapture {
        TargetCapture(
            initialSnapshot: FocusSnapshot(context: context, target: target),
            focusMonitor: StubFocusMonitor(invalidated: false)
        )
    }

    private func makeStore() -> VerifiedDeliveryStore {
        let suite = "OutputDeliveryCoordinatorTests.\(UUID().uuidString)"
        return VerifiedDeliveryStore(defaults: UserDefaults(suiteName: suite)!)
    }
}

private struct StaticProvider: MarkdownFormattingProviding {
    let output: String?

    func format(prompt: String) async -> String? { output }
}

@MainActor
private final class SnapshotTargetInspector: FocusedTargetInspecting {
    private var snapshots: [FocusSnapshot]
    private var lastSnapshot = FocusSnapshot(context: nil, target: nil)

    init(_ snapshots: [FocusSnapshot]) {
        self.snapshots = snapshots
    }

    func snapshot() -> FocusSnapshot {
        guard !snapshots.isEmpty else { return lastSnapshot }
        lastSnapshot = snapshots.removeFirst()
        return lastSnapshot
    }

}

@MainActor
private final class SequenceAttemptDeliverer: TextDelivering {
    private var results: [DeliveryAttempt]
    var methods: [DeliveryMethod] = []
    var copiedTexts: [String] = []

    init(results: [DeliveryAttempt]) {
        self.results = results
    }

    func deliver(
        _ text: String,
        method: DeliveryMethod,
        target: FocusedTarget
    ) async -> DeliveryAttempt {
        methods.append(method)
        return results.isEmpty ? .unavailable(method) : results.removeFirst()
    }

    func copy(_ text: String) -> TextDeliveryResult {
        copiedTexts.append(text)
        return text.isEmpty ? .notInserted : .copiedByUser
    }
}

private extension TargetApplication {
    static let fixture = TargetApplication(name: "TextEdit", bundleIdentifier: "com.apple.TextEdit")
}

private extension FocusContext {
    static func fixture(windowToken: UInt) -> FocusContext {
        FocusContext(
            application: .fixture,
            processIdentifier: 42,
            applicationVersion: "1.0",
            windowToken: windowToken
        )
    }
}

private extension FocusedTarget {
    static func fixture(context: FocusContext, token: UInt) -> FocusedTarget {
        FocusedTarget(
            context: context,
            accessibilityElementToken: token,
            capabilities: TextTargetCapabilities(
                role: kAXTextAreaRole as String,
                subrole: nil,
                selectedTextSettable: false,
                selectedRangeReadable: true
            )
        )
    }

    static func verifiableFixture(context: FocusContext, token: UInt) -> FocusedTarget {
        FocusedTarget(
            context: context,
            accessibilityElementToken: token,
            capabilities: TextTargetCapabilities(
                role: kAXTextAreaRole as String,
                subrole: nil,
                selectedTextSettable: true,
                selectedRangeReadable: true
            )
        )
    }

    static func secureFixture(context: FocusContext, token: UInt) -> FocusedTarget {
        FocusedTarget(
            context: context,
            accessibilityElementToken: token,
            capabilities: TextTargetCapabilities(
                role: kAXTextFieldRole as String,
                subrole: kAXSecureTextFieldSubrole as String,
                selectedTextSettable: true,
                selectedRangeReadable: true
            )
        )
    }
}

private final class StubFocusMonitor: FocusChangeMonitoring {
    let invalidated: Bool

    init(invalidated: Bool) {
        self.invalidated = invalidated
    }
}
