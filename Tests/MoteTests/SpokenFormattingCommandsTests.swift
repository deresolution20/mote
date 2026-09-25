import MoteCleanup
import Testing

@Suite struct SpokenFormattingCommandsTests {
    @Test func matchedCodeCommandsBecomeOneFencedBlock() {
        let parsed = SpokenFormattingCommands.parse(
            "start code block yaml jsonData timeout 120 end code block"
        )

        #expect(parsed.blocks == [.init(language: "yaml", body: "jsonData timeout 120")])
        #expect(parsed.textForFormatter == "[[GROTDOWN_CODE_BLOCK_0]]")
    }

    @Test func commandMatchingIsCaseAndWhitespaceInsensitive() {
        let parsed = SpokenFormattingCommands.parse(
            "START   CODE BLOCK   Swift let answer = 42 END CODE BLOCK"
        )

        #expect(parsed.blocks == [.init(language: "swift", body: "let answer = 42")])
    }

    @Test func unmatchedStartCommandRemainsLiteralSpeech() {
        let source = "start code block yaml jsonData timeout 120"
        #expect(SpokenFormattingCommands.parse(source).textForFormatter == source)
    }
}
