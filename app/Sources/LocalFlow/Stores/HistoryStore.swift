import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var records: [DictationRecord] = []
    @Published private(set) var loadError: String?

    private let fileURL: URL
    private let fileManager: FileManager

    init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.fileManager = fileManager
        load()
    }

    func append(_ record: DictationRecord) {
        records.insert(record, at: 0)
        persist()
    }

    func replace(_ record: DictationRecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index] = record
        persist()
    }

    func updateOutcome(for id: UUID, to outcome: InsertionOutcome) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index] = records[index].replacingOutcome(outcome)
        persist()
    }

    func delete(id: UUID) {
        records.removeAll { $0.id == id }
        persist()
    }

    func clear() {
        records.removeAll()
        persist()
    }

    private func load() {
        do {
            try LocalStoreProtection.prepareDirectory(
                at: fileURL.deletingLastPathComponent(),
                fileManager: fileManager
            )
            guard fileManager.fileExists(atPath: fileURL.path) else { return }
            try LocalStoreProtection.protectFile(at: fileURL, fileManager: fileManager)
            let document = try JSONDecoder.grotdown.decode(VersionedDocument.self, from: Data(contentsOf: fileURL))
            guard document.schemaVersion == 1 else {
                throw StoreError.unsupportedSchema(document.schemaVersion)
            }
            records = document.values
        } catch {
            loadError = "Could not read dictation history: \(error.localizedDescription)"
        }
    }

    private func persist() {
        guard loadError == nil else { return }

        do {
            try LocalStoreProtection.prepareDirectory(
                at: fileURL.deletingLastPathComponent(),
                fileManager: fileManager
            )
            let document = VersionedDocument(schemaVersion: 1, values: records)
            let data = try JSONEncoder.grotdown.encode(document)
            try data.write(to: fileURL, options: .atomic)
            try LocalStoreProtection.protectFile(at: fileURL, fileManager: fileManager)
        } catch {
            loadError = "Could not save dictation history: \(error.localizedDescription)"
        }
    }

    private static func defaultFileURL() -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Grotdown", isDirectory: true)
        return directory.appendingPathComponent("history.json")
    }
}

private struct VersionedDocument: Codable {
    let schemaVersion: Int
    let values: [DictationRecord]
}

private enum StoreError: LocalizedError {
    case unsupportedSchema(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version): return "Unsupported history schema version \(version)."
        }
    }
}

extension JSONEncoder {
    static var grotdown: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var grotdown: JSONDecoder {
        let decoder = JSONDecoder()
        return decoder
    }
}
