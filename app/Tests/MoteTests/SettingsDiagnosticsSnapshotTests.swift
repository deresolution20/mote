import Testing
@testable import MoteCleanup

@Suite struct SettingsDiagnosticsSnapshotTests {
    @Test func formatsCurrentDiagnosticsForSettings() {
        let snapshot = SettingsDiagnosticsSnapshot(
            status: "Mote ready — ⌥ Space",
            cleanupDisplayName: "MLX",
            cleanupModel: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
            insertionMode: "Automatic",
            lastRawTranscript: "um so ship it friday",
            lastCleanedText: "Ship it Friday."
        )

        #expect(snapshot.cleanupModelLabel == "MLX: mlx-community/Qwen2.5-1.5B-Instruct-4bit")
        #expect(snapshot.insertionModeLabel == "Automatic")
        #expect(snapshot.rawTranscriptDisplay == "um so ship it friday")
        #expect(snapshot.cleanedTextDisplay == "Ship it Friday.")
    }

    @Test func usesPlaceholdersWhenNoDictationHasRun() {
        let snapshot = SettingsDiagnosticsSnapshot(
            status: "Permissions needed",
            cleanupDisplayName: "MLX",
            cleanupModel: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
            insertionMode: "Compatibility",
            lastRawTranscript: "",
            lastCleanedText: ""
        )

        #expect(snapshot.insertionModeLabel == "Compatibility")
        #expect(snapshot.rawTranscriptDisplay == "No dictation yet.")
        #expect(snapshot.cleanedTextDisplay == "No cleaned text yet.")
    }
}
