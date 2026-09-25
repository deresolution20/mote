import Foundation

enum MarkdownFormattingSafety {
    static func accepts(
        _ candidate: String,
        source: String,
        markers: [String],
        preserveCodeAndBackticks: Bool
    ) -> Bool {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard !trimmed.contains("```") else { return false }
        guard !trimmed.contains("](") else { return false }
        guard !trimmed.contains("<"), !trimmed.contains(">") else { return false }
        guard !hasAssistantWrapper(trimmed) else { return false }
        guard !hasUnexpectedMarker(in: trimmed, allowed: markers) else { return false }
        guard markerCountsAreExact(in: trimmed, markers: markers) else { return false }
        guard hasOnlyAllowedLineStructure(trimmed) else { return false }

        if preserveCodeAndBackticks, source.contains("`") {
            return false
        }

        let candidateWords = words(in: trimmed, removing: markers)
        let sourceWords = words(in: source, removing: markers)
        return candidateWords == sourceWords
    }

    private static func hasAssistantWrapper(_ text: String) -> Bool {
        let firstLine = text
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        return firstLine.hasPrefix("here is")
            || firstLine.hasPrefix("here's")
            || firstLine == "markdown:"
            || firstLine == "formatted markdown:"
    }

    private static func hasUnexpectedMarker(in text: String, allowed markers: [String]) -> Bool {
        let markerPattern = #"\[\[GROTDOWN_CODE_BLOCK_\d+\]\]"#
        guard let expression = try? NSRegularExpression(pattern: markerPattern) else { return true }
        let matches = expression.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.contains { match in
            guard let range = Range(match.range, in: text) else { return true }
            return !markers.contains(String(text[range]))
        }
    }

    private static func markerCountsAreExact(in text: String, markers: [String]) -> Bool {
        markers.allSatisfy { text.components(separatedBy: $0).count == 2 }
    }

    private static func hasOnlyAllowedLineStructure(_ text: String) -> Bool {
        text.split(separator: "\n", omittingEmptySubsequences: false).allSatisfy { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { return true }
            guard !line.hasPrefix(">"), !line.hasPrefix("|") else { return false }
            guard !line.hasPrefix("[") || line.hasPrefix("[[GROTDOWN_CODE_BLOCK_") else { return false }

            return !line.contains("<")
                && !line.contains(">")
                && !line.contains("```")
        }
    }

    private static func words(in text: String, removing markers: [String]) -> [String] {
        let withoutMarkers = markers.reduce(text) { partial, marker in
            partial.replacingOccurrences(of: marker, with: " ")
        }
        return withoutMarkers
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }
    }
}
