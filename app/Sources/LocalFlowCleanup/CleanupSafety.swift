import Foundation

enum CleanupSafety {
    private static let nonMeaningFillerPhrases = [
        ["you", "know"],
        ["i", "mean"],
        ["um"],
        ["uh"],
        ["erm"],
        ["like"],
        ["so"],
        ["okay"],
        ["yeah"],
        ["basically"],
    ]

    static func acceptedCandidate(from rawOutput: String, raw: String) -> String? {
        evaluate(rawOutput: rawOutput, raw: raw).acceptedText
    }

    static func evaluate(rawOutput: String, raw: String) -> CleanupSafetyEvaluation {
        let sanitized = sanitize(rawOutput)
        if let rejection = sanitized.rejection {
            return CleanupSafetyEvaluation(
                acceptedText: nil,
                sanitizedCandidate: sanitized.text,
                rejection: rejection
            )
        }
        guard let sanitizedText = sanitized.text else {
            return CleanupSafetyEvaluation(
                acceptedText: nil,
                sanitizedCandidate: nil,
                rejection: CleanupRejection(reason: .unknown)
            )
        }
        if let rejection = CleanupPlausibility.evaluate(sanitizedText, raw: raw) {
            return CleanupSafetyEvaluation(
                acceptedText: nil,
                sanitizedCandidate: sanitizedText,
                rejection: rejection
            )
        }
        if let addedToken = firstAddedMeaningToken(in: sanitizedText, raw: raw) {
            return CleanupSafetyEvaluation(
                acceptedText: nil,
                sanitizedCandidate: sanitizedText,
                rejection: CleanupRejection(reason: .addedMeaningToken, detail: addedToken)
            )
        }
        return CleanupSafetyEvaluation(
            acceptedText: sanitizedText,
            sanitizedCandidate: sanitizedText,
            rejection: nil
        )
    }

    private static func sanitize(_ rawOutput: String) -> (text: String?, rejection: CleanupRejection?) {
        var text = rawOutput
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            return (nil, CleanupRejection(reason: .emptyOutput))
        }
        guard let unfenced = stripSurroundingCodeFence(text) else {
            return (nil, CleanupRejection(reason: .codeFenceArtifact))
        }
        text = unfenced
        text = stripKnownPrefix(from: text)
        guard !hasAssistantStyleWrapper(text) else {
            return (text, CleanupRejection(reason: .assistantWrapper))
        }
        guard !hasForbiddenMarkdownOrLink(text) else {
            return (text, CleanupRejection(reason: .forbiddenMarkdownOrLink))
        }
        guard !hasBulletPrefix(text) else {
            return (text, CleanupRejection(reason: .bulletList))
        }

        text = stripInlineFormatting(from: text)
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard lines.count == 1 else {
            return (text, CleanupRejection(reason: .multilineOutput))
        }

        return (collapseWhitespace(in: lines[0]), nil)
    }

    private static func stripSurroundingCodeFence(_ text: String) -> String? {
        guard text.hasPrefix("```") else {
            return text.contains("```") ? nil : text
        }

        let lines = text.components(separatedBy: .newlines)
        guard lines.count >= 3 else { return nil }
        guard lines[0].trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") else { return nil }
        guard lines[lines.count - 1].trimmingCharacters(in: .whitespacesAndNewlines) == "```" else { return nil }

        let body = lines.dropFirst().dropLast().joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return body.contains("```") ? nil : body
    }

    private static func stripKnownPrefix(from text: String) -> String {
        let prefixes = ["output:", "cleaned text:", "cleaned:"]
        let lowercased = text.lowercased()
        for prefix in prefixes where lowercased.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    private static func hasAssistantStyleWrapper(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let prefixes = [
            "here is",
            "here's",
            "sure",
            "certainly",
            "the cleaned text is",
            "the cleaned version is",
            "cleaned version:",
            "as an ai",
        ]
        return prefixes.contains { lowercased.hasPrefix($0) }
    }

    private static func hasForbiddenMarkdownOrLink(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        if lowercased.contains("http://") || lowercased.contains("https://") || lowercased.contains("www.") {
            return true
        }
        if text.contains("](") || text.contains("<a ") {
            return true
        }
        return false
    }

    private static func hasBulletPrefix(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
            return true
        }

        guard let first = trimmed.first, first.isNumber else { return false }
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        return parts.first?.hasSuffix(".") == true
    }

    private static func stripInlineFormatting(from text: String) -> String {
        text
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
    }

    private static func collapseWhitespace(in text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func firstAddedMeaningToken(in cleaned: String, raw: String) -> String? {
        let rawVariants = Set(normalizedWords(raw).flatMap(canonicalVariants))
        let cleanedTokens = normalizedWords(cleaned)
        var index = 0

        while index < cleanedTokens.count {
            let token = cleanedTokens[index]
            if let fillerLength = fillerPhraseLength(in: cleanedTokens, startingAt: index) {
                index += fillerLength
                continue
            }
            if !canonicalVariants(for: token).contains(where: { rawVariants.contains($0) }) {
                return token
            }
            index += 1
        }
        return nil
    }

    private static func fillerPhraseLength(in tokens: [String], startingAt index: Int) -> Int? {
        for phrase in nonMeaningFillerPhrases {
            guard index + phrase.count <= tokens.count else { continue }
            if Array(tokens[index..<(index + phrase.count)]) == phrase {
                return phrase.count
            }
        }
        return nil
    }

    private static func normalizedWords(_ text: String) -> [String] {
        let cleaned = text.lowercased().map { ch -> Character in
            if ch == "’" { return "'" }
            return (ch.isLetter || ch.isNumber || ch == "'") ? ch : " "
        }
        return String(cleaned).split(separator: " ").map(String.init)
    }

    private static func canonicalVariants(for token: String) -> Set<String> {
        var variants: Set<String> = [token.replacingOccurrences(of: "'", with: "")]

        if token.hasSuffix("'s") {
            let possessiveBase = token.dropLast(2).replacingOccurrences(of: "'", with: "")
            if !possessiveBase.isEmpty {
                variants.insert(String(possessiveBase))
            }
        }

        return variants
    }
}
