import LocalFlowCleanup
import Testing
@testable import LocalFlow

@Suite struct GrotdownSettingsSnapshotTests {
    @Test func outputSettingsDescribeGFMAndCodeCommands() {
        let snapshot = GrotdownSettingsSnapshot.fixture(outputFormat: .markdown)

        #expect(snapshot.outputFormatLabel == "Markdown (GFM)")
        #expect(snapshot.codeCommandHelp.contains("start code block"))
        #expect(snapshot.codeCommandHelp.contains("end code block"))
    }

    @Test func settingsExposeTheFiveRequiredTabsAndLocalModelCopy() {
        let snapshot = GrotdownSettingsSnapshot.fixture()

        #expect(GrotdownSettingsSnapshot.tabNames == ["General", "Model", "Hotkey", "Output", "Microphone"])
        #expect(snapshot.modelDescription.contains("Parakeet"))
        #expect(snapshot.modelDescription.contains("MLX only"))
        #expect(snapshot.hotkeyLabel == "⌥ Space")
        #expect(snapshot.captureModeLabel == "Hold to talk")
    }

    @Test func toggleCaptureModeUsesItsReadableLabel() {
        let snapshot = GrotdownSettingsSnapshot.fixture(captureMode: .toggle)

        #expect(snapshot.captureModeLabel == "Tap to toggle")
    }
}
