import MoteCleanup
import Testing

@Suite struct OutputResolutionTests {
    @Test func plainOutputNeverInvokesTheFormatter() async {
        let resolver = OutputResolution(formatter: MarkdownFormatter(provider: FailingMarkdownProvider()))
        let result = await resolver.resolve(
            "Confirm the panel loads.",
            requestedFormat: .plain,
            options: .init(preserveCodeAndBackticks: false)
        )

        #expect(result == .init(
            requestedFormat: .plain,
            effectiveFormat: .plain,
            text: "Confirm the panel loads.",
            usedPlainFallback: false
        ))
    }

    @Test func unsafeMarkdownResolutionRecordsThePlainFallback() async {
        let resolver = OutputResolution(
            formatter: MarkdownFormatter(provider: StaticMarkdownProvider(output: "# A new claim"))
        )
        let result = await resolver.resolve(
            "A claim",
            requestedFormat: .markdown,
            options: .init(preserveCodeAndBackticks: false)
        )

        #expect(result == .init(
            requestedFormat: .markdown,
            effectiveFormat: .plain,
            text: "A claim",
            usedPlainFallback: true
        ))
    }
}

private struct FailingMarkdownProvider: MarkdownFormattingProviding {
    func format(prompt: String) async -> String? {
        Issue.record("The plain-output path must not format text.")
        return nil
    }
}

private struct StaticMarkdownProvider: MarkdownFormattingProviding {
    let output: String?

    func format(prompt: String) async -> String? {
        output
    }
}
