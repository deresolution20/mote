@preconcurrency import AVFoundation
import FluidAudio
import Foundation

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

            var sampleResults: [SampleResult] = []
            sampleResults.reserveCapacity(selectedSamples.count)

            for sample in selectedSamples {
                try await manager.reset()
                let sampleURL = loadedManifest.url.deletingLastPathComponent().appendingPathComponent(sample.file)
                let result = try await runSample(sample: sample, url: sampleURL, manager: manager)
                sampleResults.append(result)
            }

            let output = BenchmarkOutput(
                task: taskName,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                status: "completed",
                variant: benchmarkVariant.rawValue,
                manifestPath: loadedManifest.url.path,
                loadSeconds: loadSeconds,
                sampleCount: sampleResults.count,
                summary: BenchmarkSummary(samples: sampleResults),
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
    manager: any StreamingAsrManager
) async throws -> SampleResult {
    let file = try AVAudioFile(forReading: url)
    let chunkFrames: AVAudioFrameCount = 4096
    let partialStats = PartialStats()
    let sampleStarted = Date()

    await manager.setPartialTranscriptCallback { partial in
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
        try await manager.appendAudio(buffer)
        try await manager.processBufferedAudio()
    }

    let finishStarted = Date()
    let streamingText = try await manager.finish().trimmingCharacters(in: .whitespacesAndNewlines)
    let finalizationLatencySeconds = Date().timeIntervalSince(finishStarted)
    let totalLatencySeconds = Date().timeIntervalSince(sampleStarted)

    return SampleResult(
        id: sample.id,
        file: sample.file,
        reference: sample.reference,
        streamingText: streamingText,
        timeToFirstPartialSeconds: partialStats.firstPartialAt,
        partialCount: partialStats.count,
        finalizationLatencySeconds: finalizationLatencySeconds,
        totalLatencySeconds: totalLatencySeconds,
        wer: wordErrorRate(reference: sample.reference, hypothesis: streamingText),
        contentWER: wordErrorRate(reference: sample.reference, hypothesis: streamingText, ignoringFillers: true)
    )
}

private final class PartialStats: @unchecked Sendable {
    private let lock = NSLock()
    private var _firstPartialAt: TimeInterval?
    private var _lastPartialText = ""
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

    func recordPartial(text: String, at timestamp: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        if _firstPartialAt == nil {
            _firstPartialAt = timestamp
        }
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
          --manifest bench/samples/manifest.json, or ../bench/samples/manifest.json when run from app/
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
    let sampleCount: Int
    let summary: BenchmarkSummary
    let samples: [SampleResult]
}

private struct SampleResult: Encodable {
    let id: String
    let file: String
    let reference: String
    let streamingText: String
    let timeToFirstPartialSeconds: TimeInterval?
    let partialCount: Int
    let finalizationLatencySeconds: TimeInterval
    let totalLatencySeconds: TimeInterval
    let wer: Double
    let contentWER: Double

    private enum CodingKeys: String, CodingKey {
        case id
        case file
        case reference
        case streamingText
        case timeToFirstPartialSeconds
        case partialCount
        case finalizationLatencySeconds
        case totalLatencySeconds
        case wer
        case contentWER
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(file, forKey: .file)
        try container.encode(reference, forKey: .reference)
        try container.encode(streamingText, forKey: .streamingText)
        try container.encode(timeToFirstPartialSeconds, forKey: .timeToFirstPartialSeconds)
        try container.encode(partialCount, forKey: .partialCount)
        try container.encode(finalizationLatencySeconds, forKey: .finalizationLatencySeconds)
        try container.encode(totalLatencySeconds, forKey: .totalLatencySeconds)
        try container.encode(wer, forKey: .wer)
        try container.encode(contentWER, forKey: .contentWER)
    }
}

private struct BenchmarkSummary: Encodable {
    let sampleCount: Int
    let medianTimeToFirstPartialSeconds: TimeInterval?
    let medianFinalizationLatencySeconds: TimeInterval
    let medianTotalLatencySeconds: TimeInterval
    let meanWER: Double
    let meanContentWER: Double

    init(samples: [SampleResult]) {
        sampleCount = samples.count
        medianTimeToFirstPartialSeconds = median(samples.compactMap(\.timeToFirstPartialSeconds))
        medianFinalizationLatencySeconds = median(samples.map(\.finalizationLatencySeconds)) ?? 0
        medianTotalLatencySeconds = median(samples.map(\.totalLatencySeconds)) ?? 0
        meanWER = samples.isEmpty ? 0 : samples.map(\.wer).reduce(0, +) / Double(samples.count)
        meanContentWER = samples.isEmpty ? 0 : samples.map(\.contentWER).reduce(0, +) / Double(samples.count)
    }
}

private func defaultManifestPath() -> URL {
    let fileManager = FileManager.default
    let candidates = [
        URL(fileURLWithPath: "bench/samples/manifest.json"),
        URL(fileURLWithPath: "../bench/samples/manifest.json"),
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
            URL(fileURLWithPath: "bench/samples/manifest.json"),
            URL(fileURLWithPath: "../bench/samples/manifest.json"),
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
