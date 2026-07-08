import Foundation
import LocalFlowCleanup

private let taskName = "post-safety-production-cleanup-acceptance-benchmark"

@main
struct CleanupAcceptanceCommand {
    static func main() async {
        do {
            let options = try Options.parse(CommandLine.arguments)
            let manifest = try loadManifest(from: options.manifestPath)
            let selectedSamples = options.limit.map { Array(manifest.samples.prefix($0)) } ?? manifest.samples
            guard !selectedSamples.isEmpty else {
                throw CommandError.invalidArgument("manifest contains no samples")
            }

            let factory = CleanupProviderFactory()
            let providers = factory.providerChain
            let providerChain = providers.map { provider in
                ProviderDescriptor(
                    id: provider.id.rawValue,
                    displayName: provider.displayName,
                    modelName: provider.modelName
                )
            }

            let warmupStarted = Date()
            let warmupResult = await CleanupAcceptanceRunner.run(raw: "warm up", providers: providers)
            let warmupSeconds = Date().timeIntervalSince(warmupStarted)

            var sampleResults: [BenchmarkSampleResult] = []
            sampleResults.reserveCapacity(selectedSamples.count)

            let benchmarkStarted = Date()
            for sample in selectedSamples {
                let sampleStarted = Date()
                let result = await CleanupAcceptanceRunner.run(raw: sample.reference, providers: providers)
                let latency = Date().timeIntervalSince(sampleStarted)
                sampleResults.append(BenchmarkSampleResult(
                    id: sample.id,
                    file: sample.file,
                    reference: sample.reference,
                    latencySeconds: latency,
                    path: result.path.label,
                    attemptedProviders: result.attemptedProviders.map(\.rawValue),
                    attempts: result.attempts.map(BenchmarkAttempt.init),
                    textToPaste: result.textToPaste,
                    cleanedText: result.cleanedText
                ))
            }
            let benchmarkSeconds = Date().timeIntervalSince(benchmarkStarted)

            let output = BenchmarkOutput(
                task: taskName,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                status: "completed",
                selectedProvider: CleanupProviderID.mlx.rawValue,
                providerChain: providerChain,
                manifestPath: options.manifestPath.path,
                sampleCount: sampleResults.count,
                warmupSeconds: warmupSeconds,
                warmupPath: warmupResult.path.label,
                benchmarkSeconds: benchmarkSeconds,
                summary: BenchmarkSummary(samples: sampleResults),
                samples: sampleResults,
                notes: [
                    "This measures the production cleanup chain after one warmup call in the same process.",
                    "The measured chain is MLX cleanup, then raw transcript fallback.",
                    "Automated safety gates reject implausible MLX outputs; human review remains required for accepted-output quality and raw fallback review.",
                ]
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
            let failure = [
                "task": taskName,
                "status": "failed",
                "error": String(describing: error),
            ]
            if let data = try? JSONSerialization.data(withJSONObject: failure, options: [.prettyPrinted, .sortedKeys]) {
                FileHandle.standardError.write(data)
                FileHandle.standardError.write(Data("\n".utf8))
            }
            Foundation.exit(1)
        }
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
          local-flow-cleanup-acceptance [--manifest PATH] [--output PATH] [--limit N]

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
    case missingManifest([String])

    var description: String {
        switch self {
        case .invalidArgument(let message):
            return message
        case .missingManifest(let candidates):
            return "could not find manifest at any candidate path: \(candidates.joined(separator: ", "))"
        }
    }
}

private struct Manifest: Decodable {
    let samples: [ManifestSample]
}

private struct ManifestSample: Decodable {
    let file: String
    let id: String
    let reference: String
}

private struct ProviderDescriptor: Encodable {
    let id: String
    let displayName: String
    let modelName: String
}

private struct BenchmarkOutput: Encodable {
    let task: String
    let createdAt: String
    let status: String
    let selectedProvider: String
    let providerChain: [ProviderDescriptor]
    let manifestPath: String
    let sampleCount: Int
    let warmupSeconds: TimeInterval
    let warmupPath: String
    let benchmarkSeconds: TimeInterval
    let summary: BenchmarkSummary
    let samples: [BenchmarkSampleResult]
    let notes: [String]
}

private struct BenchmarkSampleResult: Encodable {
    let id: String
    let file: String
    let reference: String
    let latencySeconds: TimeInterval
    let path: String
    let attemptedProviders: [String]
    let attempts: [BenchmarkAttempt]
    let textToPaste: String
    let cleanedText: String?
}

private struct BenchmarkAttempt: Encodable {
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
    let minSeconds: TimeInterval
    let maxSeconds: TimeInterval
    let meanSeconds: TimeInterval
    let medianSeconds: TimeInterval
    let p90Seconds: TimeInterval
    let p95Seconds: TimeInterval
    let mlxCount: Int
    let rawFallbackCount: Int
    let rejectedAttemptCount: Int
    let timeoutAttemptCount: Int
    let errorAttemptCount: Int
    let requiresManualReview: Bool
    let automatedDecision: String

    init(samples: [BenchmarkSampleResult]) {
        let latencies = samples.map(\.latencySeconds).sorted()
        sampleCount = samples.count
        minSeconds = latencies.first ?? 0
        maxSeconds = latencies.last ?? 0
        meanSeconds = latencies.isEmpty ? 0 : latencies.reduce(0, +) / Double(latencies.count)
        medianSeconds = Self.percentile(0.5, values: latencies)
        p90Seconds = Self.percentile(0.9, values: latencies)
        p95Seconds = Self.percentile(0.95, values: latencies)
        mlxCount = samples.filter { $0.path == CleanupProviderID.mlx.rawValue }.count
        rawFallbackCount = samples.filter { $0.path == CleanupAcceptancePath.rawFallback.label }.count
        let attempts = samples.flatMap(\.attempts)
        rejectedAttemptCount = attempts.filter { $0.outcome == CleanupProviderOutcome.rejected.rawValue }.count
        timeoutAttemptCount = attempts.filter { $0.outcome == CleanupProviderOutcome.timeout.rawValue }.count
        errorAttemptCount = attempts.filter { $0.outcome == CleanupProviderOutcome.error.rawValue }.count
        requiresManualReview = true
        automatedDecision = rawFallbackCount == 0 ? "latency_and_output_review_required" : "hold_for_raw_fallback_review"
    }

    private static func percentile(_ percentile: Double, values: [TimeInterval]) -> TimeInterval {
        guard !values.isEmpty else { return 0 }
        if values.count == 1 { return values[0] }
        let rank = percentile * Double(values.count - 1)
        let lower = Int(rank.rounded(.down))
        let upper = Int(rank.rounded(.up))
        if lower == upper { return values[lower] }
        let weight = rank - Double(lower)
        return values[lower] * (1 - weight) + values[upper] * weight
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

private func loadManifest(from url: URL) throws -> Manifest {
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
    return try JSONDecoder().decode(Manifest.self, from: data)
}
