import Darwin
import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import MLXSpikeSupport
import Tokenizers

@main
struct MLXCleanupSpike {
    static func main() async {
        let options: SpikeOptions
        do {
            options = try SpikeOptions.parse(Array(CommandLine.arguments.dropFirst()))
        } catch {
            fputs("ERROR: \(error.localizedDescription)\n", stderr)
            exit(64)
        }

        if options.workerMode {
            let result = await runSpike(options: options)
            do {
                try write(result, to: options.outputURL)
                print("Result written to \(options.outputURL.path)")
            } catch {
                fputs("ERROR: failed to write result JSON: \(error)\n", stderr)
                exit(1)
            }

            exit(result.status == .loadedAndGenerated ? 0 : 1)
        }

        let status = runObservedWorker(options: options)
        exit(status)
    }

    private static func runObservedWorker(options: SpikeOptions) -> Int32 {
        let workerOutputURL = options.outputURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(options.outputURL.deletingPathExtension().lastPathComponent)-worker-\(UUID().uuidString).json")
        let executableURL = URL(fileURLWithPath: CommandLine.arguments[0])

        do {
            try MLXMetallibRuntime.validateAvailable(nextToExecutable: executableURL)
        } catch let error as MLXMetallibPreparationError {
            writeToolchainBlockedResult(options: options, blocker: error.description)
            return 1
        } catch {
            writeToolchainBlockedResult(options: options, blocker: String(describing: error))
            return 1
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = options.workerArguments(outputURL: workerOutputURL)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try FileManager.default.createDirectory(
                at: options.outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try process.run()
            process.waitUntilExit()
        } catch {
            writeToolchainBlockedResult(
                options: options,
                blocker: "Failed to launch MLX worker process: \(error)"
            )
            return 1
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !output.isEmpty {
            print(output)
        }

        if FileManager.default.fileExists(atPath: workerOutputURL.path) {
            do {
                let data = try Data(contentsOf: workerOutputURL)
                _ = try JSONSerialization.jsonObject(with: data)
                try data.write(to: options.outputURL, options: .atomic)
                try? FileManager.default.removeItem(at: workerOutputURL)
            } catch {
                writeToolchainBlockedResult(
                    options: options,
                    blocker: "MLX worker produced invalid result JSON: \(error)"
                )
                return 1
            }
            return process.terminationStatus
        }

        let statusDescription: String
        switch process.terminationReason {
        case .exit:
            statusDescription = "exit status \(process.terminationStatus)"
        case .uncaughtSignal:
            statusDescription = "signal \(process.terminationStatus)"
        @unknown default:
            statusDescription = "unknown termination \(process.terminationStatus)"
        }
        let blocker = ([statusDescription, output].filter { !$0.isEmpty }).joined(separator: "\n")
        writeToolchainBlockedResult(options: options, blocker: blocker)
        return 1
    }

    private static func writeToolchainBlockedResult(options: SpikeOptions, blocker: String) {
        let result = MLXSpikeResult.blocked(
            status: .packageOrToolchainBlocked,
            prompt: options.prompt,
            blocker: blocker,
            notes: [
                "The MLX worker did not produce result JSON.",
                "This wrapper exists because native MLX may abort in C++ before Swift can catch an error."
            ],
            swiftToolchain: commandOutput("/usr/bin/env", arguments: ["swift", "--version"]),
            machineContext: machineContext()
        )

        do {
            try write(result, to: options.outputURL)
            print("Result written to \(options.outputURL.path)")
        } catch {
            fputs("ERROR: failed to write blocked result JSON: \(error)\n", stderr)
        }
    }

    private static func runSpike(options: SpikeOptions) async -> MLXSpikeResult {
        let swiftToolchain = commandOutput("/usr/bin/env", arguments: ["swift", "--version"])
        let machineContext = machineContext()
        let notes = [
            "Native Swift package path; no oMLX app, Ollama server, or Python helper.",
            "Target model is the approved 4-bit MLX Hugging Face artifact."
        ]

        let configuration = LLMRegistry.qwen2_5_1_5b
        let loadStart = Date()

        do {
            print("Loading \(MLXSpikeConstants.modelID) through MLX Swift LM...")
            let container = try await LLMModelFactory.shared.loadContainer(
                from: #hubDownloader(),
                using: #huggingFaceTokenizerLoader(),
                configuration: configuration
            )
            let loadSeconds = Date().timeIntervalSince(loadStart)
            let parameters = GenerateParameters(maxTokens: options.maxTokens, temperature: 0)

            do {
                print("Running warmup generation...")
                let warmupStart = Date()
                _ = try await generate(
                    container: container,
                    prompt: "Reply with OK.",
                    parameters: parameters
                )
                let warmupSeconds = Date().timeIntervalSince(warmupStart)

                print("Running cleanup generation...")
                let generationStart = Date()
                let rawOutput = try await generate(
                    container: container,
                    prompt: options.prompt,
                    parameters: parameters
                )
                let generationSeconds = Date().timeIntervalSince(generationStart)

                return MLXSpikeResult.loadedAndGenerated(
                    loadSeconds: loadSeconds,
                    warmupSeconds: warmupSeconds,
                    generationSeconds: generationSeconds,
                    prompt: options.prompt,
                    rawOutput: rawOutput,
                    cleanedOutputCandidate: cleanupCandidate(from: rawOutput),
                    notes: notes + [
                        "Loaded with LLMRegistry.qwen2_5_1_5b.",
                        "Tokenizer and quantized weights loaded through MLXHuggingFace."
                    ],
                    swiftToolchain: swiftToolchain,
                    machineContext: machineContext
                )
            } catch {
                return MLXSpikeResult.loadedButGenerationFailed(
                    loadSeconds: loadSeconds,
                    warmupSeconds: nil,
                    prompt: options.prompt,
                    blocker: String(describing: error),
                    notes: notes + [
                        "Model container loaded, but generation did not complete."
                    ],
                    swiftToolchain: swiftToolchain,
                    machineContext: machineContext
                )
            }
        } catch {
            return MLXSpikeResult.blocked(
                status: status(for: error),
                prompt: options.prompt,
                blocker: String(describing: error),
                notes: notes + [
                    "Attempted LLMModelFactory.shared.loadContainer with LLMRegistry.qwen2_5_1_5b."
                ],
                swiftToolchain: swiftToolchain,
                machineContext: machineContext
            )
        }
    }

    private static func generate(
        container: ModelContainer,
        prompt: String,
        parameters: GenerateParameters
    ) async throws -> String {
        let input = try await container.prepare(input: UserInput(prompt: prompt))
        let stream = try await container.generate(input: input, parameters: parameters)
        var output = ""
        for await item in stream {
            if case .chunk(let chunk) = item {
                output += chunk
            }
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanupCandidate(from rawOutput: String) -> String {
        rawOutput
            .replacingOccurrences(of: "Output:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func status(for error: Error) -> MLXSpikeStatus {
        let message = String(describing: error).lowercased()
        if message.contains("unsupported") || message.contains("model_type") || message.contains("model type") {
            return .modelNotSupported
        }
        return .setupBlocked
    }

    private static func write(_ result: MLXSpikeResult, to outputURL: URL) throws {
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.localFlowSpike.encode(result)
        try data.write(to: outputURL, options: .atomic)
    }

    private static func machineContext() -> [String: String] {
        var context = MLXSpikeResult.defaultMachineContext()
        let architecture = commandOutput("/usr/bin/env", arguments: ["uname", "-m"])
        if !architecture.isEmpty {
            context["architecture"] = architecture
        }
        return context
    }

    private static func commandOutput(_ executablePath: String, arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            return ""
        }
    }
}

struct SpikeOptions {
    let outputURL: URL
    let prompt: String
    let maxTokens: Int
    let workerMode: Bool

    static func parse(_ arguments: [String]) throws -> SpikeOptions {
        var outputURL = defaultOutputURL()
        var prompt = MLXSpikeConstants.defaultPrompt
        var maxTokens = 80
        var workerMode = false
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--worker":
                workerMode = true
            case "--output":
                outputURL = URL(fileURLWithPath: try value(after: argument, in: arguments, at: &index))
            case "--prompt":
                prompt = try value(after: argument, in: arguments, at: &index)
            case "--max-tokens":
                let raw = try value(after: argument, in: arguments, at: &index)
                guard let parsed = Int(raw), parsed > 0 else {
                    throw SpikeCLIError.invalidValue(argument, raw)
                }
                maxTokens = parsed
            case "--help", "-h":
                throw SpikeCLIError.helpRequested
            default:
                throw SpikeCLIError.unknownArgument(argument)
            }
            index += 1
        }

        return SpikeOptions(
            outputURL: outputURL,
            prompt: prompt,
            maxTokens: maxTokens,
            workerMode: workerMode
        )
    }

    func workerArguments(outputURL: URL) -> [String] {
        [
            "--worker",
            "--output", outputURL.path,
            "--prompt", prompt,
            "--max-tokens", String(maxTokens)
        ]
    }

    private static func defaultOutputURL() -> URL {
        let current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let repositoryRoot = current.lastPathComponent == "bench" ? current.deletingLastPathComponent() : current
        return repositoryRoot
            .appendingPathComponent("docs")
            .appendingPathComponent("reports")
            .appendingPathComponent("mlx-cleanup-benchmark")
            .appendingPathComponent("runs")
            .appendingPathComponent("2026-07-06-task-3-swift-native-mlx-spike")
            .appendingPathComponent("mlx-swift-spike-result.json")
    }

    private static func value(after argument: String, in arguments: [String], at index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw SpikeCLIError.missingValue(argument)
        }
        index = valueIndex
        return arguments[valueIndex]
    }
}

enum SpikeCLIError: LocalizedError {
    case helpRequested
    case invalidValue(String, String)
    case missingValue(String)
    case unknownArgument(String)

    var errorDescription: String? {
        switch self {
        case .helpRequested:
            return """
            Usage: mlx-cleanup-spike [--output PATH] [--prompt TEXT] [--max-tokens COUNT]
            """
        case .invalidValue(let argument, let value):
            return "\(argument) received invalid value '\(value)'"
        case .missingValue(let argument):
            return "\(argument) requires a value"
        case .unknownArgument(let argument):
            return "unknown argument '\(argument)'"
        }
    }
}
