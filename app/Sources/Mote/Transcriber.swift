import FluidAudio
import Foundation

/// Parakeet TDT v3 via FluidAudio — the Phase-0 benchmark winner
/// (13.6% WER, 72 ms median on Brice's voice; see bench/RESULTS.md).
final class Transcriber {
    private var manager: AsrManager?

    func load() async throws {
        let models = try await AsrModels.downloadAndLoad(version: .v3)
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        self.manager = manager
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        guard let manager else {
            throw NSError(domain: "Mote", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "transcriber used before load()"
            ])
        }
        var decoderState = TdtDecoderState.make()
        let result = try await manager.transcribe(samples, decoderState: &decoderState)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
