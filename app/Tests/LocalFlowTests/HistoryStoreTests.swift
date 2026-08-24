import Foundation
import LocalFlowCleanup
import Testing
@testable import LocalFlow

@MainActor
@Suite struct HistoryStoreTests {
    @Test func historyRoundTripsAndUpdatesOutcome() throws {
        let url = try temporaryFileURL(named: "history.json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = HistoryStore(fileURL: url)
        let record = DictationRecord.fixture(finalText: "# Incident update", format: .markdown)
        store.append(record)
        store.updateOutcome(for: record.id, to: .copiedNoFocusedTarget)

        let restored = HistoryStore(fileURL: url)
        #expect(restored.records == [record.replacingOutcome(.copiedNoFocusedTarget)])
    }

    @Test func historyIsNewestFirstAndCanDeleteOrClear() throws {
        let url = try temporaryFileURL(named: "history.json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = HistoryStore(fileURL: url)
        let first = DictationRecord.fixture(finalText: "first")
        let second = DictationRecord.fixture(finalText: "second")
        store.append(first)
        store.append(second)

        #expect(store.records.map(\.id) == [second.id, first.id])
        store.delete(id: second.id)
        #expect(store.records == [first])
        store.clear()
        #expect(store.records.isEmpty)
    }

    @Test func historyWritesAVersionOneEnvelope() throws {
        let url = try temporaryFileURL(named: "history.json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = HistoryStore(fileURL: url)
        store.append(.fixture(finalText: "Saved"))

        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        #expect(object?["schemaVersion"] as? Int == 1)
    }

    @Test func persistedHistoryUsesOwnerOnlyPermissions() throws {
        let url = try temporaryFileURL(named: "history.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = HistoryStore(fileURL: url)
        store.append(.fixture(finalText: "Private meeting notes"))

        #expect(try posixPermissions(of: url.deletingLastPathComponent()) == 0o700)
        #expect(try posixPermissions(of: url) == 0o600)
        #expect(try url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }

    @Test func corruptedHistoryIsReportedWithoutOverwritingTheSource() throws {
        let url = try temporaryFileURL(named: "history.json")
        defer { try? FileManager.default.removeItem(at: url) }
        let corrupted = "not valid JSON"
        try Data(corrupted.utf8).write(to: url)

        let store = HistoryStore(fileURL: url)
        store.append(.fixture(finalText: "Never overwrite the evidence"))

        #expect(store.records.count == 1)
        #expect(store.loadError != nil)
        #expect(try String(contentsOf: url, encoding: .utf8) == corrupted)
    }
}

private func temporaryFileURL(named name: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LocalFlowTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appendingPathComponent(name)
}

private func posixPermissions(of url: URL) throws -> Int {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    return (attributes[.posixPermissions] as? NSNumber)?.intValue ?? -1
}

private extension DictationRecord {
    static func fixture(finalText: String, format: OutputFormat = .plain) -> DictationRecord {
        DictationRecord(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_721_000_000),
            duration: 0.8,
            rawText: finalText,
            finalText: finalText,
            format: format,
            targetApplication: nil,
            insertionOutcome: .pending
        )
    }
}
