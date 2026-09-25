@preconcurrency import AVFoundation
import FluidAudio
import Foundation
import MoteCleanup

private let taskName = "streaming-hud-asr-benchmark"
private let benchmarkVariant = StreamingModelVariant.parakeetEou160ms

@main
struct StreamingBenchmarkCommand {
    static func main() async {
        do {
            let options = try Options.parse(CommandLine.arguments)
            let loadedManifest = try loadManifest(from: options.manifestPath)
            let selectedSamples = options.limit.map { Array(loadedManifest.manifest.samples.prefix($0)) }
                ?? loadedManifest.manifest.samples
            guard !selectedSamples.isEmpty else {
                throw CommandError.invalidArgument("manifest contains no samples")
            }

            let manager = benchmarkVariant.createManager()
            let loadStarted = Date()
            try await manager.loadModels()
            let loadSeconds = Date().timeIntervalSince(loadStarted)

            let tdtLoadStarted = Date()
            let tdtModels = try await AsrModels.downloadAndLoad(version: .v3)
            let tdtManager = AsrManager(config: .default)
            try await tdtManager.loadModels(tdtModels)
            let tdtLoadSeconds = Date().timeIntervalSince(tdtLoadStarted)
            let cleanupProviders = CleanupProviderFactory().providerChain
            cleanupProviders.forEach { $0.warmUp() }

            var sampleResults: [SampleResult] = []
            sampleResults.reserveCapacity(selectedSamples.count)

            for sample in selectedSamples {
                try await manager.reset()
                let sampleURL = loadedManifest.url.deletingLastPathComponent().appendingPathComponent(sample.file)
                let result = try await runSample(
                    sample: sample,
                    url: sampleURL,
                    streamingManager: manager,
                    tdtManager: tdtManager,
                    cleanupProviders: cleanupProviders
                )
                sampleResults.append(result)
            }
            let summary = BenchmarkSummary(samples: sampleResults)

            let output = BenchmarkOutput(
                task: taskName,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                status: "completed",
                variant: benchmarkVariant.rawValue,
                manifestPath: loadedManifest.url.path,
                loadSeconds: loadSeconds,
                tdtLoadSeconds: tdtLoadSeconds,
                sampleCount: sampleResults.count,
                summary: summary,
                promotionDecision: summary.promotionDecision,
                promotionRationale: summary.promotionRationale,
                samples: sampleResults
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(output)

            if let outputPath = options.outputPath {
                try FileManager.default.createDirectory(
                    at: outputPath.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: outputPath, options: .atomic)
            } else {
                FileHandle.standardOutput.write(data)
                FileHandle.standardOutput.write(Data("\n".utf8))
            }
        } catch {
            FileHandle.standardError.write(Data("streaming benchmark failed: \(error)\n".utf8))
            Foundation.exit(1)
        }
    }
}

private func runSample(
    sample: ManifestSample,
    url: URL,
    streamingManager: any StreamingAsrManager,
    tdtManager: AsrManager,
    cleanupProviders: [any CleanupProvider]
) async throws -> SampleResult {
    let file = try AVAudioFile(forReading: url)
    let chunkFrames: AVAudioFrameCount = 4096
    let partialStats = PartialStats()
    let sampleStarted = Date()

    await streamingManager.setPartialTranscriptCallback { partial in
        guard !partial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        partialStats.recordPartial(text: partial, at: Date().timeIntervalSince(sampleStarted))
    }

    while file.framePosition < file.length {
        let remaining = AVAudioFrameCount(file.length - file.framePosition)
        let frames = min(chunkFrames, remaining)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames) else {
            throw CommandError.invalidAudioBuffer
        }
        try file.read(into: buffer, frameCount: frames)
        guard buffer.frameLength > 0 else { continue }
        try await streamingManager.appendAudio(buffer)
        try await streamingManager.processBufferedAudio()
    }

    let finishStarted = Date()
    let streamingText = try await streamingManager.finish().trimmingCharacters(in: .whitespacesAndNewlines)
    let finalizationLatencySeconds = Date().timeIntervalSince(finishStarted)
    let totalLatencySeconds = Date().timeIntervalSince(sampleStarted)
    let tdtStarted = Date()
    var decoderState = TdtDecoderState.make()
    let tdtText = try await tdtManager.transcribe(url, decoderState: &decoderState)
        .text
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let tdtLatencySeconds = Date().timeIntervalSince(tdtStarted)
    let correctedStreamingText = PersonalDictionary.shared.correct(streamingText)
    let cleanupStarted = Date()
    let cleanupResult = await CleanupAcceptanceRunner.run(raw: correctedStreamingText, providers: cleanupProviders)
    let cleanupLatencySeconds = Date().timeIntervalSince(cleanupStarted)

    return SampleResult(
        id: sample.id,
        file: sample.file,
        reference: sample.reference,
        streamingText: streamingText,
        tdtText: tdtText,
        timeToFirstPartialSeconds: partialStats.firstPartialAt,
        partialCount: partialStats.count,
        partialUpdateCadenceSeconds: partialStats.cadenceSeconds,
        finalizationLatencySeconds: finalizationLatencySeconds,
        totalLatencySeconds: totalLatencySeconds,
        tdtLatencySeconds: tdtLatencySeconds,
        wer: wordErrorRate(reference: sample.reference, hypothesis: streamingText),
        contentWER: wordErrorRate(reference: sample.reference, hypothesis: streamingText, ignoringFillers: true),
        tdtWER: wordErrorRate(reference: sample.reference, hypothesis: tdtText),
        tdtContentWER: wordErrorRate(reference: sample.reference, hypothesis: tdtText, ignoringFillers: true),
        correctedStreamingText: correctedStreamingText,
        streamingCleanup: CleanupResultSummary(
            result: cleanupResult,
            latencySeconds: cleanupLatencySeconds
        )
    )
}

private final class PartialStats: @unchecked Sendable {
    private let lock = NSLock()
    private var _firstPartialAt: TimeInterval?
    private var _lastPartialText = ""
    private var _partialTimestamps: [TimeInterval] = []
    private var _count = 0

    var firstPartialAt: TimeInterval? {
        lock.lock()
        defer { lock.unlock() }
        return _firstPartialAt
    }

    var lastPartialText: String {
        lock.lock()
        defer { lock.unlock() }
        return _lastPartialText
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return _count
    }

    var cadenceSeconds: [TimeInterval] {
        lock.lock()
        defer { lock.unlock() }
        guard _partialTimestamps.count > 1 else { return [] }
        return zip(_partialTimestamps.dropFirst(), _partialTimestamps)
            .map { current, previous in current - previous }
    }

    func recordPartial(text: String, at timestamp: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        if _firstPartialAt == nil {
            _firstPartialAt = timestamp
        }
        _partialTimestamps.append(timestamp)
        _lastPartialText = text
        _count += 1
    }
}

private struct Options {
    let manifestPath: URL
    let outputPath: URL?
    let limit: Int?

    static func parse(_ arguments: [String]) throws -> Options {
        var manifestPath: URL?
        var outputPath: URL?
        var limit: Int?

        var index = 1
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--manifest":
                manifestPath = URL(fileURLWithPath: try value(after: argument, in: arguments, at: &index))
            case "--output":
                outputPath = URL(fileURLWithPath: try value(after: argument, in: arguments, at: &index))
            case "--limit":
                let raw = try value(after: argument, in: arguments, at: &index)
                guard let parsed = Int(raw), parsed > 0 else {
                    throw CommandError.invalidArgument("--limit must be a positive integer")
                }
                limit = parsed
            case "--help", "-h":
                throw CommandError.invalidArgument(Self.help)
            default:
                throw CommandError.invalidArgument("unknown argument \(argument)\n\n\(Self.help)")
            }
            index += 1
        }

        return Options(
            manifestPath: manifestPath ?? defaultManifestPath(),
            outputPath: outputPath,
            limit: limit
        )
    }

    private static var help: String {
        """
        Usage:
          local-flow-streaming-benchmark [--manifest PATH] [--output PATH] [--limit N]

        Defaults:
          --manifest Tools/Bench/samples/manifest.json, or samples/manifest.json when run from Tools/Bench/
        """
    }

    private static func value(after argument: String, in arguments: [String], at index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw CommandError.invalidArgument("missing value for \(argument)")
        }
        index = valueIndex
        return arguments[valueIndex]
    }
}

private enum CommandError: Error, CustomStringConvertible {
    case invalidArgument(String)
    case invalidAudioBuffer
    case missingManifest([String])

    var description: String {
        switch self {
        case .invalidArgument(let message):
            return message
        case .invalidAudioBuffer:
            return "could not allocate audio buffer"
        case .missingManifest(let candidates):
            return "could not find manifest at any candidate path: \(candidates.joined(separator: ", "))"
        }
    }
}

private struct LoadedManifest {
    let manifest: Manifest
    let url: URL
}

private struct Manifest: Decodable {
    let samples: [ManifestSample]
}

private struct ManifestSample: Decodable {
    let file: String
    let id: String
    let reference: String
}

private struct BenchmarkOutput: Encodable {
    let task: String
    let createdAt: String
    let status: String
    let variant: String
    let manifestPath: String
    let loadSeconds: TimeInterval
    let tdtLoadSeconds: TimeInterval
    let sampleCount: Int
    let summary: BenchmarkSummary
    let promotionDecision: String
    let promotionRationale: String
    let samples: [SampleResult]
}

private struct SampleResult: Encodable {
    let id: String
    let file: String
    let reference: String
    let streamingText: String
    let tdtText: String
    let timeToFirstPartialSeconds: TimeInterval?
    let partialCount: Int
    let partialUpdateCadenceSeconds: [TimeInterval]
    let finalizationLatencySeconds: TimeInterval
    let totalLatencySeconds: TimeInterval
    let tdtLatencySeconds: TimeInterval
    let wer: Double
    let contentWER: Double
    let tdtWER: Double
    let tdtContentWER: Double
    let correctedStreamingText: String
    let streamingCleanup: CleanupResultSummary

    private enum CodingKeys: String, CodingKey {
        case id
        case file
        case reference
        case streamingText
        case tdtText
        case timeToFirstPartialSeconds
        case partialCount
        case partialUpdateCadenceSeconds
        case finalizationLatencySeconds
        case totalLatencySeconds
        case tdtLatencySeconds
        case wer
        case contentWER
        case tdtWER
        case tdtContentWER
        case correctedStreamingText
        case streamingCleanup
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(file, forKey: .file)
        try container.encode(reference, forKey: .reference)
        try container.encode(streamingText, forKey: .streamingText)
        try container.encode(tdtText, forKey: .tdtText)
        try container.encode(timeToFirstPartialSeconds, forKey: .timeToFirstPartialSeconds)
        try container.encode(partialCount, forKey: .partialCount)
        try container.encode(partialUpdateCadenceSeconds, forKey: .partialUpdateCadenceSeconds)
        try container.encode(finalizationLatencySeconds, forKey: .finalizationLatencySeconds)
        try container.encode(totalLatencySeconds, forKey: .totalLatencySeconds)
        try container.encode(tdtLatencySeconds, forKey: .tdtLatencySeconds)
        try container.encode(wer, forKey: .wer)
        try container.encode(contentWER, forKey: .contentWER)
        try container.encode(tdtWER, forKey: .tdtWER)
        try container.encode(tdtContentWER, forKey: .tdtContentWER)
        try container.encode(correctedStreamingText, forKey: .correctedStreamingText)
        try container.encode(streamingCleanup, forKey: .streamingCleanup)
    }
}

private struct CleanupResultSummary: Encodable {
    let path: String
    let latencySeconds: TimeInterval
    let attemptedProviders: [String]
    let textToPaste: String
    let cleanedText: String?
    let attempts: [CleanupAttemptSummary]

    init(result: CleanupAcceptanceResult, latencySeconds: TimeInterval) {
        path = result.path.label
        self.latencySeconds = latencySeconds
        attemptedProviders = result.attemptedProviders.map(\.rawValue)
        textToPaste = result.textToPaste
        cleanedText = result.cleanedText
        attempts = result.attempts.map(CleanupAttemptSummary.init)
    }
}

private struct CleanupAttemptSummary: Encodable {
    let provider: String
    let outcome: String
    let latencySeconds: TimeInterval
    let rejectReason: String?
    let rejectDetail: String?
    let rawCandidate: String?
    let sanitizedCandidate: String?
    let cleanedText: String?
    let errorDescription: String?

    init(_ attempt: CleanupProviderAttempt) {
        provider = attempt.providerID.rawValue
        outcome = attempt.outcome.rawValue
        latencySeconds = attempt.latencySeconds
        rejectReason = attempt.rejection?.reason.rawValue
        rejectDetail = attempt.rejection?.detail
        rawCandidate = attempt.rawCandidate
        sanitizedCandidate = attempt.sanitizedCandidate
        cleanedText = attempt.cleanedText
        errorDescription = attempt.errorDescription
    }
}

private struct BenchmarkSummary: Encodable {
    let sampleCount: Int
    let medianTimeToFirstPartialSeconds: TimeInterval?
    let medianPartialCadenceSeconds: TimeInterval?
    let medianFinalizationLatencySeconds: TimeInterval
    let medianTotalLatencySeconds: TimeInterval
    let medianTDTLatencySeconds: TimeInterval
    let meanWER: Double
    let meanContentWER: Double
    let meanTDTWER: Double
    let meanTDTContentWER: Double
    let streamingContentWERBetterOrEqualCount: Int
    let streamingCleanupRawFallbackCount: Int
    let streamingCleanupAcceptedCount: Int
    let promotionDecision: String
    let promotionRationale: String

    init(samples: [SampleResult]) {
        sampleCount = samples.count
        medianTimeToFirstPartialSeconds = median(samples.compactMap(\.timeToFirstPartialSeconds))
        medianPartialCadenceSeconds = median(samples.flatMap(\.partialUpdateCadenceSeconds))
        medianFinalizationLatencySeconds = median(samples.map(\.finalizationLatencySeconds)) ?? 0
        medianTotalLatencySeconds = median(samples.map(\.totalLatencySeconds)) ?? 0
        medianTDTLatencySeconds = median(samples.map(\.tdtLatencySeconds)) ?? 0
        meanWER = samples.isEmpty ? 0 : samples.map(\.wer).reduce(0, +) / Double(samples.count)
        meanContentWER = samples.isEmpty ? 0 : samples.map(\.contentWER).reduce(0, +) / Double(samples.count)
        meanTDTWER = samples.isEmpty ? 0 : samples.map(\.tdtWER).reduce(0, +) / Double(samples.count)
        meanTDTContentWER = samples.isEmpty ? 0 : samples.map(\.tdtContentWER).reduce(0, +) / Double(samples.count)
        streamingContentWERBetterOrEqualCount = samples.filter { $0.contentWER <= $0.tdtContentWER }.count
        streamingCleanupRawFallbackCount = samples.filter {
            $0.streamingCleanup.path == CleanupAcceptancePath.rawFallback.label
        }.count
        streamingCleanupAcceptedCount = samples.count - streamingCleanupRawFallbackCount
        promotionDecision = "hold"
        if samples.isEmpty {
            promotionRationale = "No benchmark samples were processed."
        } else if meanContentWER > meanTDTContentWER {
            promotionRationale = "Hold streaming final promotion: streaming mean contentWER exceeds the accepted TDT baseline."
        } else if streamingCleanupRawFallbackCount > 0 {
            promotionRationale = "Hold streaming final promotion: streaming cleanup produced raw fallback outcomes requiring review."
        } else {
            promotionRationale = "Hold streaming final promotion pending manual review of full benchmark output and live HUD smoke evidence."
        }
    }
}

private func defaultManifestPath() -> URL {
    let fileManager = FileManager.default
    let candidates = [
        URL(fileURLWithPath: "Tools/Bench/samples/manifest.json"),
        URL(fileURLWithPath: "samples/manifest.json"),
    ]
    if let existing = candidates.first(where: { fileManager.fileExists(atPath: $0.path) }) {
        return existing
    }
    return candidates[0]
}

private func loadManifest(from url: URL) throws -> LoadedManifest {
    let fileManager = FileManager.default
    let candidates: [URL]
    if fileManager.fileExists(atPath: url.path) {
        candidates = [url]
    } else {
        candidates = [
            url,
            URL(fileURLWithPath: "Tools/Bench/samples/manifest.json"),
            URL(fileURLWithPath: "samples/manifest.json"),
        ]
    }

    guard let resolved = candidates.first(where: { fileManager.fileExists(atPath: $0.path) }) else {
        throw CommandError.missingManifest(candidates.map(\.path))
    }

    let data = try Data(contentsOf: resolved)
    return LoadedManifest(
        manifest: try JSONDecoder().decode(Manifest.self, from: data),
        url: resolved
    )
}

private func median(_ values: [TimeInterval]) -> TimeInterval? {
    guard !values.isEmpty else { return nil }
    let sorted = values.sorted()
    let middle = sorted.count / 2
    if sorted.count.isMultiple(of: 2) {
        return (sorted[middle - 1] + sorted[middle]) / 2
    }
    return sorted[middle]
}

private let pureFillers: Set<String> = ["um", "uh", "erm", "uhm", "mhm", "hmm"]

private func normalizedWords(_ text: String) -> [String] {
    let cleaned = text.lowercased().map { character -> Character in
        (character.isLetter || character.isNumber || character == "'") ? character : " "
    }
    return String(cleaned).split(separator: " ").map(String.init)
}

private func wordErrorRate(reference: String, hypothesis: String, ignoringFillers: Bool = false) -> Double {
    var referenceWords = normalizedWords(reference)
    var hypothesisWords = normalizedWords(hypothesis)
    if ignoringFillers {
        referenceWords.removeAll { pureFillers.contains($0) }
        hypothesisWords.removeAll { pureFillers.contains($0) }
    }
    if referenceWords.isEmpty { return hypothesisWords.isEmpty ? 0 : Double(hypothesisWords.count) }
    if hypothesisWords.isEmpty { return 1 }

    var previous = Array(0...hypothesisWords.count)
    var current = [Int](repeating: 0, count: hypothesisWords.count + 1)

    for referenceIndex in 1...referenceWords.count {
        current[0] = referenceIndex
        for hypothesisIndex in 1...hypothesisWords.count {
            let substitution = previous[hypothesisIndex - 1]
                + (referenceWords[referenceIndex - 1] == hypothesisWords[hypothesisIndex - 1] ? 0 : 1)
            current[hypothesisIndex] = min(
                previous[hypothesisIndex] + 1,
                current[hypothesisIndex - 1] + 1,
                substitution
            )
        }
        swap(&previous, &current)
    }

    return Double(previous[hypothesisWords.count]) / Double(referenceWords.count)
}
