import Foundation

enum CleanupPlausibility {
    /// Meaning-critical markers: hedges, attribution, requests, intent. If the
    /// raw transcript has one and the cleaned text lost it, the cleanup changed
    /// meaning and must be rejected.
    private static let protectedMarkers = [
        "i think", "honestly", "maybe", "probably", "i guess", "i feel",
        "said", "i want", "i need", "can you", "could you", "we should",
    ]

    /// Hallucination guard: cleanup only ever removes fillers and fixes
    /// punctuation, so the output must be utterance-sized, built from the
    /// speaker's own words, and must keep every protected meaning marker.
    static func isPlausible(_ cleaned: String, raw: String) -> Bool {
        evaluate(cleaned, raw: raw) == nil
    }

    static func evaluate(_ cleaned: String, raw: String) -> CleanupRejection? {
        guard !cleaned.isEmpty else {
            return CleanupRejection(reason: .emptyOutput)
        }
        let rawWords = normalizedWords(raw)
        let cleanedWords = normalizedWords(cleaned)
        if cleanedWords.count > rawWords.count + 3 {
            return CleanupRejection(reason: .outputTooLong)
        }
        if rawWords.count >= 6, cleanedWords.count < rawWords.count / 3 {
            return CleanupRejection(reason: .outputTooShort)
        }

        let rawSet = Set(rawWords)
        let fromSpeaker = cleanedWords.filter { word in
            rawSet.contains(word) || rawSet.contains(String(word.prefix(while: { $0 != "'" })))
        }
        guard Double(fromSpeaker.count) >= 0.5 * Double(cleanedWords.count) else {
            return CleanupRejection(reason: .lowSpeakerOverlap)
        }

        let rawJoined = rawWords.joined(separator: " ")
        let cleanedJoined = cleanedWords.joined(separator: " ")
        for marker in protectedMarkers {
            if rawJoined.contains(marker), !cleanedJoined.contains(marker) {
                return CleanupRejection(reason: .protectedMarkerLoss, detail: marker)
            }
        }
        for term in PersonalDictionary.shared.terms {
            let t = term.lowercased()
            if rawJoined.contains(t), !cleanedJoined.contains(t) {
                return CleanupRejection(reason: .personalDictionaryTermLoss, detail: term)
            }
        }
        return nil
    }

    private static func normalizedWords(_ text: String) -> [String] {
        let cleaned = text.lowercased().map { ch -> Character in
            (ch.isLetter || ch.isNumber || ch == "'") ? ch : " "
        }
        return String(cleaned).split(separator: " ").map(String.init)
    }
}
