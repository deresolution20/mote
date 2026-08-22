import Foundation

@MainActor
final class SnippetStore: ObservableObject {
    @Published private(set) var snippets: [Snippet] = []
    @Published private(set) var loadError: String?

    private let fileURL: URL
    private let fileManager: FileManager

    init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.fileManager = fileManager
        load()
    }

    func append(_ snippet: Snippet) {
        snippets.insert(snippet, at: 0)
        persist()
    }

    func replace(_ snippet: Snippet) {
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }) else { return }
        snippets[index] = snippet
        persist()
    }

    func delete(id: UUID) {
        snippets.removeAll { $0.id == id }
        persist()
    }

    func clear() {
        snippets.removeAll()
        persist()
    }

    private func load() {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }

        do {
            let document = try JSONDecoder.grotdown.decode(VersionedSnippetDocument.self, from: Data(contentsOf: fileURL))
            guard document.schemaVersion == 1 else {
                throw SnippetStoreError.unsupportedSchema(document.schemaVersion)
            }
            snippets = document.values
        } catch {
            loadError = "Could not read snippets: \(error.localizedDescription)"
        }
    }

    private func persist() {
        guard loadError == nil else { return }

        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let document = VersionedSnippetDocument(schemaVersion: 1, values: snippets)
            let data = try JSONEncoder.grotdown.encode(document)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            loadError = "Could not save snippets: \(error.localizedDescription)"
        }
    }

    private static func defaultFileURL() -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Grotdown", isDirectory: true)
        return directory.appendingPathComponent("snippets.json")
    }
}

private struct VersionedSnippetDocument: Codable {
    let schemaVersion: Int
    let values: [Snippet]
}

private enum SnippetStoreError: LocalizedError {
    case unsupportedSchema(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version): return "Unsupported snippets schema version \(version)."
        }
    }
}
