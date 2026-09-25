public enum HUDCaptionTail {
    public static func tail(from partial: String, maxWords: Int = 5) -> String {
        guard maxWords > 0 else { return "" }

        let words = partial.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return "" }
        guard words.count > maxWords else { return words.joined(separator: " ") }

        return "..." + words.suffix(maxWords).joined(separator: " ")
    }
}
