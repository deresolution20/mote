import Foundation
import MoteCleanup
import Testing
@testable import Mote

@MainActor
@Suite struct OutputDeliveryCoordinatorTests {
    @Test func nonAutoInsertKeepsAPendingMarkdownResult() async {
        let deliverer = RecordingDeliverer()
        let coordinator = OutputDeliveryCoordinator(
            outputResolution: .init(formatter: .init(provider: StaticProvider(output: "- [ ] Confirm the panel loads"))),
            targetInspector: StubTargetInspector(target: .fixture),
            textDeliverer: deliverer
        )

        let result = await coordinator.complete(
            raw: "confirm the panel loads",
            cleaned: "Confirm the panel loads",
            format: .markdown,
            formattingOptions: .init(preserveCodeAndBackticks: false),
            autoInsert: false,
            method: .type,
            duration: 0.8
        )

        #expect(result.pending?.resolved.text == "- [ ] Confirm the panel loads")
        #expect(result.delivery == .notInserted)
        #expect(result.record.insertionOutcome == .notInserted)
        #expect(deliverer.deliveries.isEmpty)
    }

    @Test func autoInsertTypesOnlyWhenAnEditableTargetWasFound() async {
        let deliverer = RecordingDeliverer()
        let app = TargetApplication.fixture
        let coordinator = OutputDeliveryCoordinator(
            outputResolution: .init(formatter: .init(provider: StaticProvider(output: nil))),
            targetInspector: StubTargetInspector(target: .fixture),
            textDeliverer: deliverer
        )

        let result = await coordinator.complete(
            raw: "confirm the panel loads",
            cleaned: "Confirm the panel loads",
            format: .plain,
            formattingOptions: .init(preserveCodeAndBackticks: false),
            autoInsert: true,
            method: .clipboard,
            duration: 0.8
        )

        #expect(result.delivery == .typedAttempted(app))
        #expect(deliverer.deliveries == [.init(text: "Confirm the panel loads", method: .clipboard, target: app)])
        #expect(result.record.targetApplication == app)
        #expect(result.record.insertionOutcome == .typedAttempted)
    }

    @Test func noFocusedTargetCopiesAndRecordsTheHonestOutcome() async {
        let deliverer = RecordingDeliverer()
        let coordinator = OutputDeliveryCoordinator(
            outputResolution: .init(formatter: .init(provider: StaticProvider(output: nil))),
            targetInspector: StubTargetInspector(target: nil),
            textDeliverer: deliverer
        )

        let result = await coordinator.complete(
            raw: "confirm the panel loads",
            cleaned: "Confirm the panel loads",
            format: .plain,
            formattingOptions: .init(preserveCodeAndBackticks: false),
            autoInsert: true,
            method: .type,
            duration: 0.8
        )

        #expect(result.delivery == .copiedNoFocusedTarget(nil))
        #expect(result.record.insertionOutcome == .copiedNoFocusedTarget)
        #expect(deliverer.deliveries == [.init(text: "Confirm the panel loads", method: .type, target: nil)])
    }

    @Test func autoInsertKeepsPendingTextWhenFocusedTargetChangesBeforeDelivery() async {
        let deliverer = RecordingDeliverer()
        let intended = TargetApplication.fixture
        let changed = TargetApplication(name: "Notes", bundleIdentifier: "com.apple.Notes")
        let coordinator = OutputDeliveryCoordinator(
            outputResolution: .init(formatter: .init(provider: StaticProvider(output: nil))),
            targetInspector: SequenceTargetInspector(targets: [.fixture, .fixture(changed)]),
            textDeliverer: deliverer
        )

        let result = await coordinator.complete(
            raw: "confirm the panel loads",
            cleaned: "Confirm the panel loads",
            format: .plain,
            formattingOptions: .init(preserveCodeAndBackticks: false),
            autoInsert: true,
            method: .type,
            duration: 0.8
        )

        #expect(result.delivery == .notInserted)
        #expect(result.pending?.resolved.text == "Confirm the panel loads")
        #expect(result.record.targetApplication == intended)
        #expect(result.record.insertionOutcome == .notInserted)
        #expect(deliverer.deliveries.isEmpty)
    }

    @Test func autoInsertKeepsPendingTextWhenFocusedElementChangesWithinTheSameApp() async {
        let deliverer = RecordingDeliverer()
        let app = TargetApplication.fixture
        let coordinator = OutputDeliveryCoordinator(
            outputResolution: .init(formatter: .init(provider: StaticProvider(output: nil))),
            targetInspector: SequenceTargetInspector(targets: [
                .init(application: app, accessibilityElementToken: 1),
                .init(application: app, accessibilityElementToken: 2),
            ]),
            textDeliverer: deliverer
        )

        let result = await coordinator.complete(
            raw: "confirm the panel loads",
            cleaned: "Confirm the panel loads",
            format: .plain,
            formattingOptions: .init(preserveCodeAndBackticks: false),
            autoInsert: true,
            method: .type,
            duration: 0.8
        )

        #expect(result.delivery == .notInserted)
        #expect(result.pending?.resolved.text == "Confirm the panel loads")
        #expect(result.record.targetApplication == app)
        #expect(deliverer.deliveries.isEmpty)
    }

    @Test func pendingInsertionUpdatesTheOriginalRecordInsteadOfAddingAnother() async {
        let deliverer = RecordingDeliverer()
        let app = TargetApplication.fixture
        let coordinator = OutputDeliveryCoordinator(
            outputResolution: .init(formatter: .init(provider: StaticProvider(output: nil))),
            targetInspector: StubTargetInspector(target: .fixture),
            textDeliverer: deliverer
        )
        let completed = await coordinator.complete(
            raw: "reply",
            cleaned: "Reply",
            format: .plain,
            formattingOptions: .init(preserveCodeAndBackticks: false),
            autoInsert: false,
            method: .type,
            duration: 0.4
        )

        let inserted = coordinator.insert(completed.pending!, method: .type)
        #expect(inserted == .typedAttempted(app))
        #expect(completed.record.replacingOutcome(inserted.insertionOutcome).id == completed.record.id)
    }

    @Test func libraryInsertionUsesTheCurrentFocusedTarget() {
        let deliverer = RecordingDeliverer()
        let app = TargetApplication.fixture
        let coordinator = OutputDeliveryCoordinator(
            targetInspector: StubTargetInspector(target: .fixture),
            textDeliverer: deliverer
        )

        let result = coordinator.insert("Saved response", method: .type)

        #expect(result == .typedAttempted(app))
        #expect(deliverer.deliveries == [.init(text: "Saved response", method: .type, target: app)])
    }

    @Test func libraryCopyRecordsAnExplicitUserCopy() {
        let deliverer = RecordingDeliverer()
        let coordinator = OutputDeliveryCoordinator(textDeliverer: deliverer)

        let result = coordinator.copy("Saved response")

        #expect(result == .copiedByUser)
    }
}

private struct StaticProvider: MarkdownFormattingProviding {
    let output: String?

    func format(prompt: String) async -> String? { output }
}

@MainActor
private struct StubTargetInspector: FocusedTargetInspecting {
    let target: FocusedTarget?

    func focusedTarget() -> FocusedTarget? { target }
}

@MainActor
private final class SequenceTargetInspector: FocusedTargetInspecting {
    private var targets: [FocusedTarget?]

    init(targets: [FocusedTarget?]) {
        self.targets = targets
    }

    func focusedTarget() -> FocusedTarget? {
        guard !targets.isEmpty else { return nil }
        return targets.removeFirst()
    }
}

@MainActor
private final class RecordingDeliverer: TextDelivering {
    struct Delivery: Equatable {
        let text: String
        let method: TextInjector.Method
        let target: TargetApplication?
    }

    var deliveries: [Delivery] = []

    func deliver(_ text: String, method: TextInjector.Method, target: TargetApplication?) -> TextDeliveryResult {
        deliveries.append(.init(text: text, method: method, target: target))
        return target == nil ? .copiedNoFocusedTarget(nil) : .typedAttempted(target)
    }

    func copy(_ text: String) -> TextDeliveryResult {
        .copiedByUser
    }
}

private extension TargetApplication {
    static let fixture = TargetApplication(name: "TextEdit", bundleIdentifier: "com.apple.TextEdit")
}

private extension FocusedTarget {
    static var fixture: FocusedTarget {
        FocusedTarget(application: .fixture, accessibilityElementToken: 1)
    }

    static func fixture(_ application: TargetApplication) -> FocusedTarget {
        FocusedTarget(application: application, accessibilityElementToken: 2)
    }
}
