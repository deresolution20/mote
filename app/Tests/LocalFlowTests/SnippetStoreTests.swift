import Foundation
import LocalFlowCleanup
import Testing
@testable import LocalFlow

@MainActor
@Suite struct SnippetStoreTests {
    @Test func snippetCreatedFromRecordPreservesTextAndFormat() {
        let record = DictationRecord(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_721_000_000),
            duration: 1.2,
            rawText: "add an incident update",
            finalText: "## Incident update",
            format: .markdown,
            targetApplication: nil,
            insertionOutcome: .notInserted
        )

        let snippet = record.asSnippet(title: "Incident update")
        #expect(snippet.title == "Incident update")
        #expect(snippet.text == "## Incident update")
        #expect(snippet.format == .markdown)
    }

    @Test func snippetsRoundTripAndCanBeDeleted() throws {
        let url = try temporarySnippetFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = SnippetStore(fileURL: url)
        let first = Snippet(title: "Standup", text: "- [ ] Share update", format: .markdown)
        let second = Snippet(title: "Reply", text: "Thanks for the report.", format: .plain)
        store.append(first)
        store.append(second)

        let restored = SnippetStore(fileURL: url)
        #expect(restored.snippets == [second, first])
        restored.delete(id: second.id)
        #expect(restored.snippets == [first])
    }

    @Test func persistedSnippetsUseOwnerOnlyPermissions() throws {
        let url = try temporarySnippetFileURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = SnippetStore(fileURL: url)
        store.append(Snippet(title: "Private", text: "A private response", format: .plain))

        #expect(try snippetPosixPermissions(of: url.deletingLastPathComponent()) == 0o700)
        #expect(try snippetPosixPermissions(of: url) == 0o600)
        #expect(try url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }
}

private func temporarySnippetFileURL() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LocalFlowTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appendingPathComponent("snippets.json")
}

private func snippetPosixPermissions(of url: URL) throws -> Int {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    return (attributes[.posixPermissions] as? NSNumber)?.intValue ?? -1
}
