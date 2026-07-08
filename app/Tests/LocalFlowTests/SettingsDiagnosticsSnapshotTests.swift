import Testing
@testable import LocalFlowCleanup

@Suite struct SettingsDiagnosticsSnapshotTests {
    @Test func formatsCurrentDiagnosticsForSettings() {
        let snapshot = SettingsDiagnosticsSnapshot(
            status: "Ready - hold Left Option and speak",
            cleanupDisplayName: "MLX",
            cleanupModel: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
            usesDirectTyping: true,
            lastRawTranscript: "um so ship it friday",
            lastCleanedText: "Ship it Friday."
        )

        #expect(snapshot.cleanupModelLabel == "MLX: mlx-community/Qwen2.5-1.5B-Instruct-4bit")
        #expect(snapshot.insertionModeLabel == "Direct typing")
        #expect(snapshot.rawTranscriptDisplay == "um so ship it friday")
        #expect(snapshot.cleanedTextDisplay == "Ship it Friday.")
    }

    @Test func usesPlaceholdersWhenNoDictationHasRun() {
        let snapshot = SettingsDiagnosticsSnapshot(
            status: "Permissions needed",
            cleanupDisplayName: "MLX",
            cleanupModel: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
            usesDirectTyping: false,
            lastRawTranscript: "",
            lastCleanedText: ""
        )

        #expect(snapshot.insertionModeLabel == "Clipboard paste")
        #expect(snapshot.rawTranscriptDisplay == "No dictation yet.")
        #expect(snapshot.cleanedTextDisplay == "No cleaned text yet.")
    }
}
