import Foundation

/// A speech-to-text engine under benchmark. `load()` is timed separately from
/// `transcribe` because cold-start cost matters for app design but must not
/// pollute per-utterance latency.
protocol ASREngine: AnyObject {
    var name: String { get }
    func load() async throws
    func transcribe(_ audioFile: URL) async throws -> String
}

enum BenchError: Error, CustomStringConvertible {
    case engineNotLoaded(String)
    case unknownEngine(String)
    case noSamples(String)
    case ollama(String)

    var description: String {
        switch self {
        case .engineNotLoaded(let n): return "\(n) used before load()"
        case .unknownEngine(let n): return "unknown engine '\(n)' (valid: \(EngineID.allCases.map(\.rawValue).joined(separator: ", ")))"
        case .noSamples(let dir): return "no samples found in \(dir) — run `bench record` first"
        case .ollama(let msg): return "Ollama error: \(msg)"
        }
    }
}

enum EngineID: String, CaseIterable {
    case whisperTurbo = "whisperkit-turbo"
    case whisperBase = "whisperkit-base.en"
    case apple = "apple"
    case parakeet = "parakeet"

    func make() -> ASREngine {
        switch self {
        case .whisperTurbo: return WhisperKitEngine(model: "large-v3-v20240930_turbo", label: "WhisperKit large-v3-turbo")
        case .whisperBase: return WhisperKitEngine(model: "base.en", label: "WhisperKit base.en")
        case .apple: return AppleSpeechEngine()
        case .parakeet: return ParakeetEngine()
        }
    }
}
