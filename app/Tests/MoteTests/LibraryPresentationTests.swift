import Foundation
import MoteCleanup
import Testing
@testable import Mote

@Suite struct LibraryPresentationTests {
    @Test func searchMatchesRawAndFinalTextCaseInsensitively() {
        let matchingRecord = DictationRecord.libraryFixture(
            rawText: "Zendesk timeout during deploy",
            finalText: "# Deployment note"
        )
        let finalTextMatch = DictationRecord.libraryFixture(
            rawText: "Incident update",
            finalText: "The service reached its timeout threshold."
        )
        let nonMatch = DictationRecord.libraryFixture(
            rawText: "Customer feedback",
            finalText: "Follow up next week."
        )

        let presentation = LibraryPresentation(
            records: [matchingRecord, finalTextMatch, nonMatch],
            snippets: [],
            searchText: "TIMEOUT"
        )

        #expect(presentation.visibleRecords.map(\.id) == [matchingRecord.id, finalTextMatch.id])
    }

    @Test func searchMatchesSnippetTitleAndTextCaseInsensitively() {
        let titleMatch = Snippet(title: "Incident response", text: "Escalate to the on-call engineer.", format: .plain)
        let textMatch = Snippet(title: "Release notes", text: "Document the database timeout.", format: .markdown)
        let nonMatch = Snippet(title: "Follow-up", text: "Send a calendar invite.", format: .plain)

        let presentation = LibraryPresentation(
            records: [],
            snippets: [titleMatch, textMatch, nonMatch],
            searchText: "incident"
        )

        #expect(presentation.visibleSnippets.map(\.id) == [titleMatch.id])

        let textPresentation = LibraryPresentation(
            records: [],
            snippets: [titleMatch, textMatch, nonMatch],
            searchText: "TIMEOUT"
        )
        #expect(textPresentation.visibleSnippets.map(\.id) == [textMatch.id])
    }

    @Test func rowTitlesStaySingleLineAndBounded() {
        let title = LibraryPresentation.rowTitle(for: "  First line\nsecond line with a deliberately long tail that should not fill a library row  ")

        #expect(!title.contains("\n"))
        #expect(title.count <= LibraryPresentation.maximumRowTitleLength)
        #expect(title.hasSuffix("…"))
    }

    @Test func snippetTitlesUseTheFirstMeaningfulLine() {
        let title = LibraryPresentation.snippetTitle(for: "  # Incident update\n\nThe service is healthy again.  ")

        #expect(title == "Incident update")
    }

    @Test func emptySelectionDefaultsToHistory() {
        #expect(LibraryPresentation.defaultSection == .history)
    }
}

private extension DictationRecord {
    static func libraryFixture(rawText: String, finalText: String) -> DictationRecord {
        DictationRecord(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_721_000_000),
            duration: 1.5,
            rawText: rawText,
            finalText: finalText,
            format: .plain,
            targetApplication: nil,
            insertionOutcome: .pending
        )
    }
}
