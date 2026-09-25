import Foundation
import FluidAudio

final class ParakeetEngine: ASREngine {
    let name = "Parakeet v3 (FluidAudio)"
    private var manager: AsrManager?

    func load() async throws {
        let models = try await AsrModels.downloadAndLoad(version: .v3)
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        self.manager = manager
    }

    func transcribe(_ audioFile: URL) async throws -> String {
        guard let manager else { throw BenchError.engineNotLoaded(name) }
        // Fresh decoder state per utterance — each sample is an independent dictation.
        var decoderState = TdtDecoderState.make()
        let result = try await manager.transcribe(audioFile, decoderState: &decoderState)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
