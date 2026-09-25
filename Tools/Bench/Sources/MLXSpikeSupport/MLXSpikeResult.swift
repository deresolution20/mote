import Foundation

public enum MLXSpikeConstants {
    public static let task = "swift-native-mlx-provider-spike"
    public static let modelID = "mlx-community/Qwen2.5-1.5B-Instruct-4bit"
    public static let modelSource = "hugging_face"
    public static let modelLoadPath = "LLMRegistry.qwen2_5_1_5b via MLX Swift LM"
    public static let mlxSwiftPackage = "0.31.6"
    public static let mlxSwiftLMPackage = "3.31.4"
    public static let defaultPrompt = """
    Clean this dictated text. Preserve meaning. Remove only obvious filler, false starts, and stutter repetitions. Fix punctuation and capitalization. Return only the cleaned text.

    Input: um so like i think we should uh ship it friday
    """
}

public enum MLXSpikeStatus: String, Codable {
    case loadedAndGenerated = "loaded_and_generated"
    case loadedButGenerationFailed = "loaded_but_generation_failed"
    case modelNotSupported = "model_not_supported"
    case packageOrToolchainBlocked = "package_or_toolchain_blocked"
    case setupBlocked = "setup_blocked"
}

public struct MLXSpikeResult: Codable {
    public let task: String
    public let createdAt: String
    public let machineContext: [String: String]
    public let swiftToolchain: String
    public let mlxSwiftPackage: String
    public let mlxSwiftLMPackage: String
    public let modelID: String
    public let modelSource: String
    public let modelLoadPath: String?
    public let tokenizerLoadSucceeded: Bool?
    public let quantizedWeightsLoadSucceeded: Bool?
    public let loadSeconds: Double?
    public let warmupSeconds: Double?
    public let generationSeconds: Double?
    public let totalSeconds: Double?
    public let prompt: String
    public let rawOutput: String?
    public let cleanedOutputCandidate: String?
    public let status: MLXSpikeStatus
    public let blockers: [String]
    public let notes: [String]

    public init(
        task: String = MLXSpikeConstants.task,
        createdAt: String = ISO8601DateFormatter().string(from: Date()),
        machineContext: [String: String] = MLXSpikeResult.defaultMachineContext(),
        swiftToolchain: String = "unrecorded",
        mlxSwiftPackage: String = MLXSpikeConstants.mlxSwiftPackage,
        mlxSwiftLMPackage: String = MLXSpikeConstants.mlxSwiftLMPackage,
        modelID: String = MLXSpikeConstants.modelID,
        modelSource: String = MLXSpikeConstants.modelSource,
        modelLoadPath: String?,
        tokenizerLoadSucceeded: Bool?,
        quantizedWeightsLoadSucceeded: Bool?,
        loadSeconds: Double?,
        warmupSeconds: Double?,
        generationSeconds: Double?,
        totalSeconds: Double?,
        prompt: String,
        rawOutput: String?,
        cleanedOutputCandidate: String?,
        status: MLXSpikeStatus,
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
        self.tokenizerLoadSucceeded = tokenizerLoadSucceeded
        self.quantizedWeightsLoadSucceeded = quantizedWeightsLoadSucceeded
        self.loadSeconds = loadSeconds.map(Self.roundedSeconds)
        self.warmupSeconds = warmupSeconds.map(Self.roundedSeconds)
        self.generationSeconds = generationSeconds.map(Self.roundedSeconds)
        self.totalSeconds = totalSeconds.map(Self.roundedSeconds)
        self.prompt = prompt
        self.rawOutput = rawOutput
        self.cleanedOutputCandidate = cleanedOutputCandidate
        self.status = status
        self.blockers = blockers
        self.notes = notes
    }

    public static func blocked(
        status: MLXSpikeStatus,
        prompt: String,
        blocker: String,
        notes: [String] = [],
        swiftToolchain: String = "unrecorded",
        machineContext: [String: String] = MLXSpikeResult.defaultMachineContext()
    ) -> MLXSpikeResult {
        MLXSpikeResult(
            machineContext: machineContext,
            swiftToolchain: swiftToolchain,
            modelLoadPath: nil,
            tokenizerLoadSucceeded: nil,
            quantizedWeightsLoadSucceeded: nil,
            loadSeconds: nil,
            warmupSeconds: nil,
            generationSeconds: nil,
            totalSeconds: nil,
            prompt: prompt,
            rawOutput: nil,
            cleanedOutputCandidate: nil,
            status: status,
            blockers: [blocker],
            notes: notes
        )
    }

    public static func loadedAndGenerated(
        loadSeconds: Double,
        warmupSeconds: Double,
        generationSeconds: Double,
        prompt: String,
        rawOutput: String,
        cleanedOutputCandidate: String,
        notes: [String] = [],
        swiftToolchain: String = "unrecorded",
        machineContext: [String: String] = MLXSpikeResult.defaultMachineContext()
    ) -> MLXSpikeResult {
        MLXSpikeResult(
            machineContext: machineContext,
            swiftToolchain: swiftToolchain,
            modelLoadPath: MLXSpikeConstants.modelLoadPath,
            tokenizerLoadSucceeded: true,
            quantizedWeightsLoadSucceeded: true,
            loadSeconds: loadSeconds,
            warmupSeconds: warmupSeconds,
            generationSeconds: generationSeconds,
            totalSeconds: loadSeconds + warmupSeconds + generationSeconds,
            prompt: prompt,
            rawOutput: rawOutput,
            cleanedOutputCandidate: cleanedOutputCandidate,
            status: .loadedAndGenerated,
            blockers: [],
            notes: notes
        )
    }

    public static func loadedButGenerationFailed(
        loadSeconds: Double,
        warmupSeconds: Double?,
        prompt: String,
        blocker: String,
        notes: [String] = [],
        swiftToolchain: String = "unrecorded",
        machineContext: [String: String] = MLXSpikeResult.defaultMachineContext()
    ) -> MLXSpikeResult {
        let total = loadSeconds + (warmupSeconds ?? 0)
        return MLXSpikeResult(
            machineContext: machineContext,
            swiftToolchain: swiftToolchain,
            modelLoadPath: MLXSpikeConstants.modelLoadPath,
            tokenizerLoadSucceeded: true,
            quantizedWeightsLoadSucceeded: true,
            loadSeconds: loadSeconds,
            warmupSeconds: warmupSeconds,
            generationSeconds: nil,
            totalSeconds: total,
            prompt: prompt,
            rawOutput: nil,
            cleanedOutputCandidate: nil,
            status: .loadedButGenerationFailed,
            blockers: [blocker],
            notes: notes
        )
    }

    public static func defaultMachineContext() -> [String: String] {
        [
            "operating_system": ProcessInfo.processInfo.operatingSystemVersionString,
            "processor_count": String(ProcessInfo.processInfo.processorCount),
            "physical_memory_bytes": String(ProcessInfo.processInfo.physicalMemory)
        ]
    }

    private static func roundedSeconds(_ value: Double) -> Double {
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
        case tokenizerLoadSucceeded = "tokenizer_load_succeeded"
        case quantizedWeightsLoadSucceeded = "quantized_weights_load_succeeded"
        case loadSeconds = "load_seconds"
        case warmupSeconds = "warmup_seconds"
        case generationSeconds = "generation_seconds"
        case totalSeconds = "total_seconds"
        case prompt
        case rawOutput = "raw_output"
        case cleanedOutputCandidate = "cleaned_output_candidate"
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
        try container.encodeOptional(tokenizerLoadSucceeded, forKey: .tokenizerLoadSucceeded)
        try container.encodeOptional(quantizedWeightsLoadSucceeded, forKey: .quantizedWeightsLoadSucceeded)
        try container.encodeOptional(loadSeconds, forKey: .loadSeconds)
        try container.encodeOptional(warmupSeconds, forKey: .warmupSeconds)
        try container.encodeOptional(generationSeconds, forKey: .generationSeconds)
        try container.encodeOptional(totalSeconds, forKey: .totalSeconds)
        try container.encode(prompt, forKey: .prompt)
        try container.encodeOptional(rawOutput, forKey: .rawOutput)
        try container.encodeOptional(cleanedOutputCandidate, forKey: .cleanedOutputCandidate)
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

public extension JSONEncoder {
    static var localFlowSpike: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
