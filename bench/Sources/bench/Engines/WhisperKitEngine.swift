import Foundation
import WhisperKit

final class WhisperKitEngine: ASREngine {
    let name: String
    private let model: String
    private var pipe: WhisperKit?

    init(model: String, label: String) {
        self.model = model
        self.name = label
    }

    func load() async throws {
        pipe = try await WhisperKit(WhisperKitConfig(model: model))
    }

    func transcribe(_ audioFile: URL) async throws -> String {
        guard let pipe else { throw BenchError.engineNotLoaded(name) }
        let results = try await pipe.transcribe(audioPath: audioFile.path)
        return results.map(\.text).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
