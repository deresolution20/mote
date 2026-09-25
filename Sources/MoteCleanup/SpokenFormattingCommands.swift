import Foundation

public enum SpokenFormattingCommands {
    public struct CodeBlock: Equatable, Sendable {
        public let language: String?
        public let body: String

        public init(language: String?, body: String) {
            self.language = language
            self.body = body
        }
    }

    public struct Parsed: Equatable, Sendable {
        public let textForFormatter: String
        public let blocks: [CodeBlock]

        public init(textForFormatter: String, blocks: [CodeBlock]) {
            self.textForFormatter = textForFormatter
            self.blocks = blocks
        }
    }

    public static func parse(_ source: String) -> Parsed {
        let pattern = #"\bstart\s+code\s+block\b\s*(.*?)\s*\bend\s+code\s+block\b"#
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return Parsed(textForFormatter: source, blocks: [])
        }

        let range = NSRange(source.startIndex..., in: source)
        let matches = expression.matches(in: source, range: range)
        guard !matches.isEmpty else { return Parsed(textForFormatter: source, blocks: []) }

        var blocks: [CodeBlock] = []
        var replacements: [(range: Range<String.Index>, marker: String)] = []

        for match in matches {
            guard
                let fullRange = Range(match.range, in: source),
                let bodyRange = Range(match.range(at: 1), in: source)
            else {
                continue
            }

            let commandBody = String(source[bodyRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !commandBody.isEmpty else { continue }

            let block = CodeBlock.parse(commandBody)
            let marker = marker(for: blocks.count)
            blocks.append(block)
            replacements.append((fullRange, marker))
        }

        guard !replacements.isEmpty else { return Parsed(textForFormatter: source, blocks: []) }

        var textForFormatter = source
        for replacement in replacements.reversed() {
            textForFormatter.replaceSubrange(replacement.range, with: replacement.marker)
        }
        return Parsed(textForFormatter: textForFormatter, blocks: blocks)
    }

    static func restore(blocks: [CodeBlock], in candidate: String) -> String? {
        var restored = candidate
        for (index, block) in blocks.enumerated() {
            let marker = marker(for: index)
            guard restored.components(separatedBy: marker).count == 2 else { return nil }

            let fence = codeFence(for: block.body)
            let language = block.language ?? ""
            let replacement = "\(fence)\(language)\n\(block.body)\n\(fence)"
            restored = restored.replacingOccurrences(of: marker, with: replacement)
        }
        return restored
    }

    static func markers(for blocks: [CodeBlock]) -> [String] {
        blocks.indices.map(marker(for:))
    }

    private static func marker(for index: Int) -> String {
        "[[GROTDOWN_CODE_BLOCK_\(index)]]"
    }

    private static func codeFence(for body: String) -> String {
        let longestBacktickRun = body
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in line.split(separator: "`", omittingEmptySubsequences: false).dropFirst().map(\.count).max() ?? 0 }
            .max() ?? 0
        return String(repeating: "`", count: max(3, longestBacktickRun + 1))
    }
}

private extension SpokenFormattingCommands.CodeBlock {
    static let supportedLanguages: Set<String> = [
        "yaml", "json", "bash", "swift", "javascript", "typescript", "python",
    ]

    static func parse(_ commandBody: String) -> Self {
        let words = commandBody.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
        guard let first = words.first else { return Self(language: nil, body: commandBody) }

        let language = first.lowercased()
        guard supportedLanguages.contains(language), words.count == 2 else {
            return Self(language: nil, body: commandBody)
        }
        return Self(language: language, body: String(words[1]).trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
