import MoteCleanup
import Testing
@testable import Mote

@Suite struct MoteSettingsSnapshotTests {
    @Test func outputSettingsDescribeGFMAndCodeCommands() {
        let snapshot = MoteSettingsSnapshot.fixture(outputFormat: .markdown)

        #expect(snapshot.outputFormatLabel == "Markdown (GFM)")
        #expect(snapshot.codeCommandHelp.contains("start code block"))
        #expect(snapshot.codeCommandHelp.contains("end code block"))
    }

    @Test func settingsExposeTheFiveRequiredTabsAndLocalModelCopy() {
        let snapshot = MoteSettingsSnapshot.fixture()

        #expect(MoteSettingsSnapshot.tabNames == ["General", "Model", "Hotkey", "Output", "Microphone"])
        #expect(snapshot.modelDescription.contains("Parakeet"))
        #expect(snapshot.modelDescription.contains("MLX only"))
        #expect(snapshot.hotkeyLabel == "⌥ Space")
        #expect(snapshot.captureModeLabel == "Hold to talk")
    }

    @Test func toggleCaptureModeUsesItsReadableLabel() {
        let snapshot = MoteSettingsSnapshot.fixture(captureMode: .toggle)

        #expect(snapshot.captureModeLabel == "Tap to toggle")
    }

    @Test func settingsExplainTheModelDownloadConsentBoundary() {
        let unapproved = MoteSettingsSnapshot.fixture(modelDownloadsApproved: false)
        let approved = MoteSettingsSnapshot.fixture(modelDownloadsApproved: true)

        #expect(unapproved.modelDownloadDescription == "Approval required before downloading local models.")
        #expect(approved.modelDownloadDescription == "Local model downloads are approved.")
    }
}
