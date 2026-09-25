import Foundation

/// Word-level normalization: lowercase, strip everything but letters/digits/apostrophes.
/// Deliberately simple — both reference and hypothesis pass through the same rules,
/// so punctuation and casing differences never count as errors.
func normalizedWords(_ text: String) -> [String] {
    let cleaned = text.lowercased().map { ch -> Character in
        (ch.isLetter || ch.isNumber || ch == "'") ? ch : " "
    }
    return String(cleaned).split(separator: " ").map(String.init)
}

/// Unambiguous pure disfluencies. Apple SpeechTranscriber strips these with no
/// verbatim option (SDK-verified: its only TranscriptionOption is
/// etiquetteReplacements), so verbatim WER systematically penalizes it.
/// "like"/"so"/"you know" stay — they can be content words.
private let pureFillers: Set<String> = ["um", "uh", "erm", "uhm", "mhm", "hmm"]

/// Word error rate: word-level Levenshtein distance / reference word count.
/// Can exceed 1.0 when the hypothesis is much longer than the reference.
/// `ignoringFillers` drops pure disfluencies from BOTH sides first — the
/// engine-fairness metric ("content WER").
func wordErrorRate(reference: String, hypothesis: String, ignoringFillers: Bool = false) -> Double {
    var ref = normalizedWords(reference)
    var hyp = normalizedWords(hypothesis)
    if ignoringFillers {
        ref.removeAll { pureFillers.contains($0) }
        hyp.removeAll { pureFillers.contains($0) }
    }
    if ref.isEmpty { return hyp.isEmpty ? 0 : Double(hyp.count) }
    if hyp.isEmpty { return 1 }

    var previous = Array(0...hyp.count)
    var current = [Int](repeating: 0, count: hyp.count + 1)
    for i in 1...ref.count {
        current[0] = i
        for j in 1...hyp.count {
            let substitution = previous[j - 1] + (ref[i - 1] == hyp[j - 1] ? 0 : 1)
            current[j] = min(previous[j] + 1, current[j - 1] + 1, substitution)
        }
        swap(&previous, &current)
    }
    return Double(previous[hyp.count]) / Double(ref.count)
}
