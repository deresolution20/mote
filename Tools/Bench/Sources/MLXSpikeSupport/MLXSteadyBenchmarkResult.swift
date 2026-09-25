import Foundation

public enum MLXSteadyBenchmarkConstants {
    public static let task = "swift-native-mlx-steady-state-cleanup-benchmark"
}

public enum MLXSteadyBenchmarkStatus: String, Codable {
    case completed
    case generationFailed = "generation_failed"
    case packageOrToolchainBlocked = "package_or_toolchain_blocked"
    case setupBlocked = "setup_blocked"
}

public struct MLXSteadyBenchmarkSummary: Codable, Equatable {
    public let sampleCount: Int
    public let minSeconds: Double
    public let maxSeconds: Double
    public let meanSeconds: Double
    public let medianSeconds: Double
    public let p50Seconds: Double
    public let p90Seconds: Double
    public let p95Seconds: Double

    public init(latencies: [Double]) {
        let sorted = latencies.sorted()
        sampleCount = sorted.count
        minSeconds = Self.rounded(sorted.first ?? 0)
        maxSeconds = Self.rounded(sorted.last ?? 0)
        meanSeconds = Self.rounded(sorted.isEmpty ? 0 : sorted.reduce(0, +) / Double(sorted.count))
        medianSeconds = Self.rounded(Self.median(sorted))
        p50Seconds = Self.rounded(Self.percentile(0.50, sorted: sorted))
        p90Seconds = Self.rounded(Self.percentile(0.90, sorted: sorted))
        p95Seconds = Self.rounded(Self.percentile(0.95, sorted: sorted))
    }

    private static func median(_ sorted: [Double]) -> Double {
        guard !sorted.isEmpty else {
            return 0
        }
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }

    private static func percentile(_ percentile: Double, sorted: [Double]) -> Double {
        guard !sorted.isEmpty else {
            return 0
        }
        let rank = Int((Double(sorted.count - 1) * percentile).rounded())
        return sorted[rank]
    }

    private static func rounded(_ value: Double) -> Double {
        (value * 1_000).rounded() / 1_000
    }

    enum CodingKeys: String, CodingKey {
        case sampleCount = "sample_count"
        case minSeconds = "min_seconds"
        case maxSeconds = "max_seconds"
        case meanSeconds = "mean_seconds"
        case medianSeconds = "median_seconds"
        case p50Seconds = "p50_seconds"
        case p90Seconds = "p90_seconds"
        case p95Seconds = "p95_seconds"
    }
}

public struct MLXSteadyBenchmarkSample: Codable, Equatable {
    public let id: String
    public let reference: String
    public let prompt: String
    public let latencySeconds: Double
    public let rawOutput: String
    public let cleanedOutputCandidate: String

    public init(
        id: String,
        reference: String,
        prompt: String,
        latencySeconds: Double,
        rawOutput: String,
        cleanedOutputCandidate: String
    ) {
        self.id = id
        self.reference = reference
        self.prompt = prompt
        self.latencySeconds = Self.rounded(latencySeconds)
        self.rawOutput = rawOutput
        self.cleanedOutputCandidate = cleanedOutputCandidate
    }

    private static func rounded(_ value: Double) -> Double {
        (value * 1_000).rounded() / 1_000
    }

    enum CodingKeys: String, CodingKey {
        case id
        case reference
        case prompt
        case latencySeconds = "latency_seconds"
        case rawOutput = "raw_output"
        case cleanedOutputCandidate = "cleaned_output_candidate"
    }
}

public struct MLXSteadyBenchmarkResult: Codable {
    public let task: String
    public let createdAt: String
    public let machineContext: [String: String]
    public let swiftToolchain: String
    public let mlxSwiftPackage: String
    public let mlxSwiftLMPackage: String
    public let modelID: String
    public let modelSource: String
    public let modelLoadPath: String?
    public let manifestPath: String
    public let maxTokens: Int
    public let loadSeconds: Double?
    public let warmupSeconds: Double?
    public let benchmarkSeconds: Double?
    public let summary: MLXSteadyBenchmarkSummary?
    public let samples: [MLXSteadyBenchmarkSample]
    public let status: MLXSteadyBenchmarkStatus
    public let blockers: [String]
    public let notes: [String]

    public init(
        task: String = MLXSteadyBenchmarkConstants.task,
        createdAt: String = ISO8601DateFormatter().string(from: Date()),
        machineContext: [String: String] = MLXSpikeResult.defaultMachineContext(),
        swiftToolchain: String = "unrecorded",
        mlxSwiftPackage: String = MLXSpikeConstants.mlxSwiftPackage,
        mlxSwiftLMPackage: String = MLXSpikeConstants.mlxSwiftLMPackage,
        modelID: String = MLXSpikeConstants.modelID,
        modelSource: String = MLXSpikeConstants.modelSource,
        modelLoadPath: String?,
        manifestPath: String,
        maxTokens: Int,
        loadSeconds: Double?,
        warmupSeconds: Double?,
        benchmarkSeconds: Double?,
        summary: MLXSteadyBenchmarkSummary?,
        samples: [MLXSteadyBenchmarkSample],
        status: MLXSteadyBenchmarkStatus,
        blockers: [String],
        notes: [String]
    ) {
        self.task = task
        self.createdAt = createdAt
        self.machineContext = machineContext
        self.swiftToolchain = swiftToolchain
        self.mlxSwiftPackage = mlxSwiftPackage
        self.mlxSwiftLMPackage = mlxSwiftLMPackage
        self.modelID = modelID
        self.modelSource = modelSource
        self.modelLoadPath = modelLoadPath
        self.manifestPath = manifestPath
        self.maxTokens = maxTokens
        self.loadSeconds = loadSeconds.map(Self.rounded)
        self.warmupSeconds = warmupSeconds.map(Self.rounded)
        self.benchmarkSeconds = benchmarkSeconds.map(Self.rounded)
        self.summary = summary
        self.samples = samples
        self.status = status
        self.blockers = blockers
        self.notes = notes
    }

    public static func completed(
        manifestPath: String,
        maxTokens: Int = 80,
        loadSeconds: Double,
        warmupSeconds: Double,
        benchmarkSeconds: Double,
        samples: [MLXSteadyBenchmarkSample],
        notes: [String] = [],
        swiftToolchain: String = "unrecorded",
        machineContext: [String: String] = MLXSpikeResult.defaultMachineContext()
    ) -> MLXSteadyBenchmarkResult {
        MLXSteadyBenchmarkResult(
            machineContext: machineContext,
            swiftToolchain: swiftToolchain,
            modelLoadPath: MLXSpikeConstants.modelLoadPath,
            manifestPath: manifestPath,
            maxTokens: maxTokens,
            loadSeconds: loadSeconds,
            warmupSeconds: warmupSeconds,
            benchmarkSeconds: benchmarkSeconds,
            summary: MLXSteadyBenchmarkSummary(latencies: samples.map(\.latencySeconds)),
            samples: samples,
            status: .completed,
            blockers: [],
            notes: notes
        )
    }

    public static func blocked(
        status: MLXSteadyBenchmarkStatus,
        manifestPath: String,
        maxTokens: Int = 80,
        blocker: String,
        notes: [String] = [],
        swiftToolchain: String = "unrecorded",
        machineContext: [String: String] = MLXSpikeResult.defaultMachineContext()
    ) -> MLXSteadyBenchmarkResult {
        MLXSteadyBenchmarkResult(
            machineContext: machineContext,
            swiftToolchain: swiftToolchain,
            modelLoadPath: nil,
            manifestPath: manifestPath,
            maxTokens: maxTokens,
            loadSeconds: nil,
            warmupSeconds: nil,
            benchmarkSeconds: nil,
            summary: nil,
            samples: [],
            status: status,
            blockers: [blocker],
            notes: notes
        )
    }

    private static func rounded(_ value: Double) -> Double {
        (value * 1_000).rounded() / 1_000
    }

    enum CodingKeys: String, CodingKey {
        case task
        case createdAt = "created_at"
        case machineContext = "machine_context"
        case swiftToolchain = "swift_toolchain"
        case mlxSwiftPackage = "mlx_swift_package"
        case mlxSwiftLMPackage = "mlx_swift_lm_package"
        case modelID = "model_id"
        case modelSource = "model_source"
        case modelLoadPath = "model_load_path"
        case manifestPath = "manifest_path"
        case maxTokens = "max_tokens"
        case loadSeconds = "load_seconds"
        case warmupSeconds = "warmup_seconds"
        case benchmarkSeconds = "benchmark_seconds"
        case summary
        case samples
        case status
        case blockers
        case notes
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(task, forKey: .task)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(machineContext, forKey: .machineContext)
        try container.encode(swiftToolchain, forKey: .swiftToolchain)
        try container.encode(mlxSwiftPackage, forKey: .mlxSwiftPackage)
        try container.encode(mlxSwiftLMPackage, forKey: .mlxSwiftLMPackage)
        try container.encode(modelID, forKey: .modelID)
        try container.encode(modelSource, forKey: .modelSource)
        try container.encodeOptional(modelLoadPath, forKey: .modelLoadPath)
        try container.encode(manifestPath, forKey: .manifestPath)
        try container.encode(maxTokens, forKey: .maxTokens)
        try container.encodeOptional(loadSeconds, forKey: .loadSeconds)
        try container.encodeOptional(warmupSeconds, forKey: .warmupSeconds)
        try container.encodeOptional(benchmarkSeconds, forKey: .benchmarkSeconds)
        try container.encodeOptional(summary, forKey: .summary)
        try container.encode(samples, forKey: .samples)
        try container.encode(status, forKey: .status)
        try container.encode(blockers, forKey: .blockers)
        try container.encode(notes, forKey: .notes)
    }
}

private extension KeyedEncodingContainer {
    mutating func encodeOptional<T: Encodable>(_ value: T?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }
}
