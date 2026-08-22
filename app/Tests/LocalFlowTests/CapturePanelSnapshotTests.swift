import Foundation
import LocalFlowCleanup
import Testing
@testable import LocalFlow

@Suite struct CapturePanelSnapshotTests {
    @Test func readyManualInsertSnapshotShowsFormatActions() {
        let snapshot = CapturePanelSnapshot.make(
            state: .ready,
            pending: .fixture(format: .markdown, text: "# Incident update"),
            autoInsert: false,
            recentRecords: []
        )

        #expect(snapshot.showsFormatPicker)
        #expect(snapshot.primaryAction == .insert)
        #expect(snapshot.secondaryAction == .copy)
        #expect(snapshot.preview == "# Incident update")
    }

    @Test func idleSnapshotGuidesTheConfiguredHotkeyAndBoundsRecentTitles() {
        let snapshot = CapturePanelSnapshot.make(
            state: .idle,
            pending: nil,
            autoInsert: true,
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
    static func fixture(format: OutputFormat, text: String) -> PendingDictation {
        PendingDictation(
            rawText: text,
            plainText: text,
            resolved: ResolvedOutput(
                requestedFormat: format,
                effectiveFormat: format,
                text: text,
                usedPlainFallback: false
            ),
            duration: 0.4
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
