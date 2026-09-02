import Foundation

enum LibrarySection: String, CaseIterable, Hashable {
    case history
    case snippets

    var title: String {
        switch self {
        case .history: "History"
        case .snippets: "Snippets"
        }
    }

    var symbolName: String {
        switch self {
        case .history: "clock.arrow.circlepath"
        case .snippets: "bookmark"
        }
    }
}

struct LibraryPresentation {
    static let maximumRowTitleLength = 52
    static let defaultSection = LibrarySection.history

    let records: [DictationRecord]
    let snippets: [Snippet]
    let searchText: String

    var visibleRecords: [DictationRecord] {
        guard let query = normalizedSearchQuery else { return records }
        return records.filter { record in
            record.rawText.localizedCaseInsensitiveContains(query)
                || record.finalText.localizedCaseInsensitiveContains(query)
        }
    }

    var visibleSnippets: [Snippet] {
        guard let query = normalizedSearchQuery else { return snippets }
        return snippets.filter { snippet in
            snippet.title.localizedCaseInsensitiveContains(query)
                || snippet.text.localizedCaseInsensitiveContains(query)
        }
    }

    static func rowTitle(for text: String) -> String {
        let flattened = text
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard flattened.count > maximumRowTitleLength else { return flattened }
        return String(flattened.prefix(maximumRowTitleLength - 1)) + "…"
    }

    static func snippetTitle(for text: String) -> String {
        let firstMeaningfulLine = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? "Untitled snippet"
        let withoutLeadingHeading = firstMeaningfulLine
            .drop(while: { $0 == "#" })
            .trimmingCharacters(in: .whitespaces)
        let title = rowTitle(for: withoutLeadingHeading)
        return title.isEmpty ? "Untitled snippet" : title
    }

    private var normalizedSearchQuery: String? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
