public struct ResolvedOutput: Equatable, Sendable {
    public let requestedFormat: OutputFormat
    public let effectiveFormat: OutputFormat
    public let text: String
    public let usedPlainFallback: Bool

    public init(
        requestedFormat: OutputFormat,
        effectiveFormat: OutputFormat,
        text: String,
        usedPlainFallback: Bool
    ) {
        self.requestedFormat = requestedFormat
        self.effectiveFormat = effectiveFormat
        self.text = text
        self.usedPlainFallback = usedPlainFallback
    }
}

public struct OutputResolution: Sendable {
    private let formatter: MarkdownFormatter

    public init(formatter: MarkdownFormatter = MarkdownFormatter()) {
        self.formatter = formatter
    }

    public func resolve(
        _ plainText: String,
        requestedFormat: OutputFormat,
        options: FormattingOptions
    ) async -> ResolvedOutput {
        guard requestedFormat == .markdown else {
            return ResolvedOutput(
                requestedFormat: requestedFormat,
                effectiveFormat: .plain,
                text: plainText,
                usedPlainFallback: false
            )
        }

        switch await formatter.format(plainText, options: options) {
        case .formatted(let markdown):
            return ResolvedOutput(
                requestedFormat: .markdown,
                effectiveFormat: .markdown,
                text: markdown,
                usedPlainFallback: false
            )
        case .fallbackToPlain(let plainText):
            return ResolvedOutput(
                requestedFormat: .markdown,
                effectiveFormat: .plain,
                text: plainText,
                usedPlainFallback: true
            )
        }
    }
}
