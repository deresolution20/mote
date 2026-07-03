import Foundation
import AVFoundation
import Speech

/// Apple's on-device SpeechAnalyzer/SpeechTranscriber (macOS 26+).
final class AppleSpeechEngine: ASREngine {
    let name = "Apple SpeechTranscriber"
    private let locale = Locale(identifier: "en_US")
    private var ready = false

    func load() async throws {
        // A throwaway module to drive the one-time model-asset install.
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
        ready = true
    }

    func transcribe(_ audioFile: URL) async throws -> String {
        guard ready else { throw BenchError.engineNotLoaded(name) }
        // Analyzer sessions are single-use; build a fresh module per file.
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let file = try AVAudioFile(forReading: audioFile)

        async let collected: String = {
            var out = ""
            for try await result in transcriber.results where result.isFinal {
                out += String(result.text.characters)
            }
            return out
        }()

        if let lastSample = try await analyzer.analyzeSequence(from: file) {
            try await analyzer.finalizeAndFinish(through: lastSample)
        } else {
            await analyzer.cancelAndFinishNow()
        }
        return try await collected.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
