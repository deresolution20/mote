import Testing
@testable import MoteCleanup

@Suite struct MenuRuntimeSnapshotTests {
    @Test func formatsNoDictationRuntimeConsole() {
        let snapshot = MenuRuntimeSnapshot(
            statusLabel: "Mote ready — ⌥ Space",
            control: .pause,
            lastRawTranscript: "",
            lastCleanedText: ""
        )

        #expect(snapshot.statusLabel == "Mote ready — ⌥ Space")
        #expect(snapshot.controlTitle == "Pause Dictation")
        #expect(snapshot.hasLastDictation == false)
        #expect(snapshot.rawPreview == nil)
        #expect(snapshot.cleanedPreview == nil)
        #expect(snapshot.canCopyRaw == false)
        #expect(snapshot.canCopyCleaned == false)
    }

    @Test func exposesRawFallbackCopyOnly() {
        let snapshot = MenuRuntimeSnapshot(
            statusLabel: "Paused",
            control: .resume,
            lastRawTranscript: "yeah the uh the new hire starts monday i think",
            lastCleanedText: ""
        )

        #expect(snapshot.controlTitle == "Resume Dictation")
        #expect(snapshot.hasLastDictation)
        #expect(snapshot.rawPreview == "Raw: \"yeah the uh the new hire starts monday i think\"")
        #expect(snapshot.cleanedPreview == nil)
        #expect(snapshot.canCopyRaw)
        #expect(snapshot.canCopyCleaned == false)
    }

    @Test func exposesCleanedCopyWhenPresent() {
        let snapshot = MenuRuntimeSnapshot(
            statusLabel: "Ready",
            control: .pause,
            lastRawTranscript: "um so like i think we should uh ship it friday",
            lastCleanedText: "I think we should ship it Friday."
        )

        #expect(snapshot.rawPreview == "Raw: \"um so like i think we should uh ship it friday\"")
        #expect(snapshot.cleanedPreview == "Cleaned: \"I think we should ship it Friday.\"")
        #expect(snapshot.canCopyRaw)
        #expect(snapshot.canCopyCleaned)
    }

    @Test func truncatesLongTranscriptPreviews() {
        let snapshot = MenuRuntimeSnapshot(
            statusLabel: "Ready",
            control: .none,
            lastRawTranscript: "the query takes forever when i add the group by and then open the dashboard again",
            lastCleanedText: "",
            previewLimit: 30
        )

        #expect(snapshot.controlTitle == nil)
        #expect(snapshot.rawPreview == "Raw: \"the query takes forever when i...\"")
    }
}
