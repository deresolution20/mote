public protocol MarkdownFormattingProviding: Sendable {
    func format(prompt: String) async -> String?
}

public struct FormattingOptions: Equatable, Sendable {
    public let preserveCodeAndBackticks: Bool

    public init(preserveCodeAndBackticks: Bool) {
        self.preserveCodeAndBackticks = preserveCodeAndBackticks
    }
}

public enum MarkdownFormattingResult: Equatable {
    case formatted(String)
    case fallbackToPlain(String)
}

public struct MarkdownFormatter: Sendable {
    private let provider: any MarkdownFormattingProviding

    public init(provider: any MarkdownFormattingProviding = MLXMarkdownProvider()) {
        self.provider = provider
    }

    public func format(
        _ plainText: String,
        options: FormattingOptions
    ) async -> MarkdownFormattingResult {
        let parsed = SpokenFormattingCommands.parse(plainText)
        guard let candidate = await provider.format(prompt: Self.prompt(for: parsed.textForFormatter)) else {
            return .fallbackToPlain(plainText)
        }
        guard MarkdownFormattingSafety.accepts(
            candidate,
            source: parsed.textForFormatter,
            markers: SpokenFormattingCommands.markers(for: parsed.blocks),
            preserveCodeAndBackticks: options.preserveCodeAndBackticks
        ) else {
            return .fallbackToPlain(plainText)
        }
        guard let restored = SpokenFormattingCommands.restore(blocks: parsed.blocks, in: candidate) else {
            return .fallbackToPlain(plainText)
        }
        return .formatted(restored.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func prompt(for text: String) -> String {
        """
        Convert the dictated text below to GitHub-Flavored Markdown only when structure is clearly implied. You may add only Markdown punctuation, headings, list markers, task-list markers, and line breaks. Preserve every spoken word in the same order. Do not add, remove, or substitute words. Do not write links, HTML, explanations, labels, or code fences. Preserve every [[GROTDOWN_CODE_BLOCK_n]] marker exactly once.

        Dictation:
        \(text)
        """
    }
}

public struct MLXMarkdownProvider: MarkdownFormattingProviding {
    public init() {}

    public func format(prompt: String) async -> String? {
        try? await MLXTextGenerator.shared.generate(prompt: prompt, maxTokens: 256, temperature: 0)
    }
}
