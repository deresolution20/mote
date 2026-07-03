import Foundation

struct Sample: Codable {
    let id: String
    let file: String       // relative to the samples directory
    let reference: String  // verbatim words spoken, INCLUDING fillers
}

struct Manifest: Codable {
    var samples: [Sample] = []

    static func url(in dir: URL) -> URL { dir.appendingPathComponent("manifest.json") }

    static func load(from dir: URL) throws -> Manifest {
        let url = url(in: dir)
        guard FileManager.default.fileExists(atPath: url.path) else { return Manifest() }
        return try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
    }

    func save(to dir: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: Manifest.url(in: dir))
    }
}
