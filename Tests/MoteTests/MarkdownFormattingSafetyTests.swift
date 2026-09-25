import MoteCleanup
import Testing

@Suite struct MarkdownFormattingSafetyTests {
    @Test func unsafeFormatterOutputFallsBackToPlain() async {
        let provider = StubMarkdownProvider(output: "# Invented heading\nNew claim")
        let result = await MarkdownFormatter(provider: provider).format(
            "The customer said alerts fire twice.",
            options: .init(preserveCodeAndBackticks: false)
        )

        #expect(result == .fallbackToPlain("The customer said alerts fire twice."))
    }

    @Test func validTaskListWithTheSameWordsIsAccepted() async {
        let provider = StubMarkdownProvider(output: "- [ ] Confirm the panel loads")
        let result = await MarkdownFormatter(provider: provider).format(
            "Confirm the panel loads",
            options: .init(preserveCodeAndBackticks: false)
        )

        #expect(result == .formatted("- [ ] Confirm the panel loads"))
    }

    @Test func linksAndMissingMarkersFallBackToPlain() async {
        let linked = MarkdownFormatter(provider: StubMarkdownProvider(output: "[Confirm](https://example.com) the panel loads"))
        let linkedResult = await linked.format(
            "Confirm the panel loads",
            options: .init(preserveCodeAndBackticks: false)
        )
        #expect(linkedResult == .fallbackToPlain("Confirm the panel loads"))

        let missingMarker = MarkdownFormatter(provider: StubMarkdownProvider(output: "No marker here"))
        let missingMarkerResult = await missingMarker.format(
            "start code block yaml key value end code block",
            options: .init(preserveCodeAndBackticks: false)
        )
        #expect(missingMarkerResult == .fallbackToPlain("start code block yaml key value end code block"))
    }

    @Test func matchedCommandsRestoreTheOriginalCodeBody() async {
        let provider = StubMarkdownProvider(output: "[[GROTDOWN_CODE_BLOCK_0]]")
        let result = await MarkdownFormatter(provider: provider).format(
            "start code block yaml jsonData timeout 120 end code block",
            options: .init(preserveCodeAndBackticks: false)
        )

        #expect(result == .formatted("```yaml\njsonData timeout 120\n```"))
    }
}

private struct StubMarkdownProvider: MarkdownFormattingProviding {
    let output: String?

    func format(prompt: String) async -> String? {
        output
    }
}
