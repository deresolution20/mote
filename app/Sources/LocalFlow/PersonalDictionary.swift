import Foundation

/// User-defined vocabulary (proper nouns, jargon) that ASR tends to mishear.
/// Applied as a correction pass on the raw transcript before cleanup: each
/// spoken token is fuzzy-matched against the terms and, when close enough,
/// replaced with the canonical spelling — e.g. "Grafani's" → "Grafana".
final class PersonalDictionary {
    static let shared = PersonalDictionary()
    private static let key = "personalDictionary"

    private(set) var terms: [String] {
        didSet { UserDefaults.standard.set(terms, forKey: Self.key) }
    }

    init() {
        terms = UserDefaults.standard.stringArray(forKey: Self.key) ?? []
    }

    func add(_ term: String) {
        let t = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !terms.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) else { return }
        terms.append(t)
    }

    func remove(_ term: String) {
        terms.removeAll { $0 == term }
    }

    /// Rewrites tokens in `text` that phonetically resemble a dictionary term.
    /// Whitespace and punctuation are preserved; only word cores are replaced.
    func correct(_ text: String) -> String {
        guard !terms.isEmpty else { return text }
        var output = ""
        var word = ""

        func flushWord() {
            if !word.isEmpty {
                output += canonical(for: word) ?? word
                word = ""
            }
        }

        for ch in text {
            if ch.isLetter || ch.isNumber || ch == "'" {
                word.append(ch)
            } else {
                flushWord()
                output.append(ch)
            }
        }
        flushWord()
        return output
    }

    /// Returns the canonical spelling if `word` matches a term, else nil.
    private func canonical(for word: String) -> String? {
        let w = normalize(word)
        guard w.count >= 3 else { return nil } // don't touch tiny words

        for term in terms {
            let t = normalize(term)
            if w == t {
                // Right word — enforce the term's canonical casing (kubernetes → Kubernetes),
                // but don't rewrite if it already matches exactly.
                return word == term ? nil : term
            }
            guard w.first == t.first else { continue } // proper nouns keep their initial
            let distance = levenshtein(w, t)
            let ratio = Double(distance) / Double(max(w.count, t.count))
            // Tight thresholds + shared initial + matching phonetic key keeps
            // this from rewriting ordinary words that merely rhyme.
            if (distance <= 2 || ratio <= 0.34), soundex(w) == soundex(t) {
                return term
            }
        }
        return nil
    }

    private func normalize(_ s: String) -> String {
        String(s.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }
}

// MARK: - matching primitives

private func levenshtein(_ a: String, _ b: String) -> Int {
    let x = Array(a), y = Array(b)
    if x.isEmpty { return y.count }
    if y.isEmpty { return x.count }
    var prev = Array(0...y.count)
    var cur = [Int](repeating: 0, count: y.count + 1)
    for i in 1...x.count {
        cur[0] = i
        for j in 1...y.count {
            let cost = x[i - 1] == y[j - 1] ? 0 : 1
            cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
        }
        swap(&prev, &cur)
    }
    return prev[y.count]
}

/// Classic Soundex phonetic key — cheap and good at catching mishearings that
/// share sound but not spelling.
private func soundex(_ s: String) -> String {
    let upper = Array(s.uppercased().unicodeScalars.filter { CharacterSet.uppercaseLetters.contains($0) }.map(Character.init))
    guard let first = upper.first else { return "" }

    func code(_ c: Character) -> Character? {
        switch c {
        case "B", "F", "P", "V": return "1"
        case "C", "G", "J", "K", "Q", "S", "X", "Z": return "2"
        case "D", "T": return "3"
        case "L": return "4"
        case "M", "N": return "5"
        case "R": return "6"
        default: return nil
        }
    }

    var result = String(first)
    var lastCode = code(first)
    for c in upper.dropFirst() {
        let digit = code(c)
        if let digit, digit != lastCode {
            result.append(digit)
            if result.count == 4 { break }
        }
        // vowels (nil, except h/w) reset the run so repeats across them count
        if c != "H", c != "W" { lastCode = digit }
    }
    return String((result + "000").prefix(4))
}
