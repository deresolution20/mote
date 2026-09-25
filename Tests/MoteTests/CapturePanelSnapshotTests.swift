import Foundation
import MoteCleanup
import Testing
@testable import Mote

@Suite struct CapturePanelSnapshotTests {
    @Test func readyManualInsertSnapshotShowsFormatActions() {
        let snapshot = CapturePanelSnapshot.make(
            state: .ready,
            pending: .fixture(format: .markdown, text: "# Incident update"),
            recentRecords: []
        )

        #expect(snapshot.showsFormatPicker)
        #expect(snapshot.primaryAction == .insert)
        #expect(snapshot.secondaryAction == .copy)
        #expect(snapshot.preview == "# Incident update")
        #expect(snapshot.pendingTitle == "Ready to insert")
        #expect(snapshot.primaryActionTitle == "Insert")
    }

    @Test func pendingSafetyFallbackShowsManualActionsEvenWhenAutoInsertIsOn() {
        let snapshot = CapturePanelSnapshot.make(
            state: .idle,
            pending: .fixture(format: .plain, text: "Review the change before inserting it."),
            recentRecords: []
        )

        #expect(snapshot.showsFormatPicker)
        #expect(snapshot.primaryAction == .insert)
        #expect(snapshot.secondaryAction == .copy)
    }

    @Test func secureFieldBlockExplainsThatNoAutomaticInsertionOccurred() {
        let snapshot = CapturePanelSnapshot.make(
            state: .idle,
            pending: .fixture(
                format: .plain,
                text: "Sensitive text",
                deliveryReason: .blocked(.secureField)
            ),
            recentRecords: []
        )

        #expect(snapshot.pendingTitle == "Secure field protected")
        #expect(snapshot.pendingDetail == "Mote never inserts automatically into secure text fields.")
        #expect(snapshot.primaryActionTitle == "Try again here")
    }

    @Test func unverifiedDeliveryWarnsBeforeAUserInitiatedRetry() {
        let snapshot = CapturePanelSnapshot.make(
            state: .idle,
            pending: .fixture(
                format: .plain,
                text: "Possibly inserted",
                deliveryReason: .unverified(.directEvents)
            ),
            recentRecords: []
        )

        #expect(snapshot.pendingTitle == "Insertion could not be verified")
        #expect(snapshot.pendingDetail == "The text may already be present. Inserting again could duplicate it.")
        #expect(snapshot.primaryActionTitle == "Insert again")
    }

    @Test func modelDownloadApprovalGuidesTheUserToOnboarding() {
        let snapshot = CapturePanelSnapshot.make(
            state: .needsModelDownloadApproval,
            pending: nil,
            recentRecords: []
        )

        #expect(snapshot.guidance == "Approve local model download to begin")
    }

    @Test func idleSnapshotGuidesTheConfiguredHotkeyAndBoundsRecentTitles() {
        let snapshot = CapturePanelSnapshot.make(
            state: .idle,
            pending: nil,
            recentRecords: [.fixture(finalText: "This transcript title is deliberately longer than thirty characters.")]
        )

        #expect(snapshot.guidance == "Use ⌥ Space to dictate")
        #expect(snapshot.recentTitles == ["This transcript title is deli…"])
    }

    @Test func formatLabelsDescribeBothSupportedOutputModes() {
        #expect(CapturePanelSnapshot.formatLabel(for: .plain) == "Plain text")
        #expect(CapturePanelSnapshot.formatLabel(for: .markdown) == "Markdown")
    }
}

private extension PendingDictation {
    static func fixture(
        format: OutputFormat,
        text: String,
        deliveryReason: PendingDeliveryReason = .manual
    ) -> PendingDictation {
        PendingDictation(
            rawText: text,
            plainText: text,
            resolved: ResolvedOutput(
                requestedFormat: format,
                effectiveFormat: format,
                text: text,
                usedPlainFallback: false
            ),
            duration: 0.4,
            deliveryReason: deliveryReason
        )
    }
}

private extension DictationRecord {
    static func fixture(finalText: String) -> DictationRecord {
        DictationRecord(
            id: UUID(),
            createdAt: .now,
            duration: 0.4,
            rawText: finalText,
            finalText: finalText,
            format: .plain,
            targetApplication: nil,
            insertionOutcome: .pending
        )
    }
}
