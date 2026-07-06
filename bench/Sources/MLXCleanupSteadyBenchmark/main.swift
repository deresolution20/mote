import Darwin
import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import MLXSpikeSupport
import Tokenizers

@main
struct MLXCleanupSteadyBenchmark {
    static func main() async {
        let options: BenchmarkOptions
        do {
            options = try BenchmarkOptions.parse(Array(CommandLine.arguments.dropFirst()))
        } catch {
            fputs("ERROR: \(error.localizedDescription)\n", stderr)
            exit(64)
        }

        if options.workerMode {
            let result = await runBenchmark(options: options)
            do {
                try write(result, to: options.outputURL)
                print("Result written to \(options.outputURL.path)")
            } catch {
                fputs("ERROR: failed to write result JSON: \(error)\n", stderr)
                exit(1)
            }

            exit(result.status == .completed ? 0 : 1)
        }

        let status = runObservedWorker(options: options)
        exit(status)
    }

    private static func runObservedWorker(options: BenchmarkOptions) -> Int32 {
        let workerOutputURL = options.outputURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(options.outputURL.deletingPathExtension().lastPathComponent)-worker-\(UUID().uuidString).json")
        let executableURL = URL(fileURLWithPath: CommandLine.arguments[0])

        do {
            try MLXMetallibRuntime.validateAvailable(nextToExecutable: executableURL)
        } catch let error as MLXMetallibPreparationError {
            writeBlockedResult(options: options, status: .packageOrToolchainBlocked, blocker: error.description)
            return 1
        } catch {
            writeBlockedResult(options: options, status: .packageOrToolchainBlocked, blocker: String(describing: error))
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
            writeBlockedResult(
                options: options,
                status: .packageOrToolchainBlocked,
                blocker: "Failed to launch MLX benchmark worker process: \(error)"
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
                writeBlockedResult(
                    options: options,
                    status: .packageOrToolchainBlocked,
                    blocker: "MLX benchmark worker produced invalid result JSON: \(error)"
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
        writeBlockedResult(options: options, status: .packageOrToolchainBlocked, blocker: blocker)
        return 1
    }

    private static func runBenchmark(options: BenchmarkOptions) async -> MLXSteadyBenchmarkResult {
        let swiftToolchain = commandOutput("/usr/bin/env", arguments: ["swift", "--version"])
        let machineContext = machineContext()
        let samples: [BenchmarkSample]
        do {
            samples = try BenchmarkManifest.load(from: options.manifestURL).samplesForRun(limit: options.limit)
        } catch {
            return MLXSteadyBenchmarkResult.blocked(
                status: .setupBlocked,
                manifestPath: options.manifestPathForOutput,
                maxTokens: options.maxTokens,
                blocker: "Failed to load benchmark manifest: \(error)",
                notes: notes(),
                swiftToolchain: swiftToolchain,
                machineContext: machineContext
            )
        }

        let configuration = LLMRegistry.qwen2_5_1_5b
        let loadStart = Date()

        do {
            print("Loading \(MLXSpikeConstants.modelID) once through MLX Swift LM...")
            let container = try await LLMModelFactory.shared.loadContainer(
                from: #hubDownloader(),
                using: #huggingFaceTokenizerLoader(),
                configuration: configuration
            )
            let loadSeconds = Date().timeIntervalSince(loadStart)
            let parameters = GenerateParameters(maxTokens: options.maxTokens, temperature: 0)

            print("Running one warmup generation...")
            let warmupStart = Date()
            _ = try await generate(container: container, prompt: "Reply with OK.", parameters: parameters)
            let warmupSeconds = Date().timeIntervalSince(warmupStart)

            var benchmarkSamples: [MLXSteadyBenchmarkSample] = []
            let benchmarkStart = Date()
            for sample in samples {
                let prompt = cleanupPrompt(reference: sample.reference)
                let sampleStart = Date()
                let rawOutput = try await generate(container: container, prompt: prompt, parameters: parameters)
                let latencySeconds = Date().timeIntervalSince(sampleStart)
                benchmarkSamples.append(
                    MLXSteadyBenchmarkSample(
                        id: sample.id,
                        reference: sample.reference,
                        prompt: prompt,
                        latencySeconds: latencySeconds,
                        rawOutput: rawOutput,
                        cleanedOutputCandidate: cleanupCandidate(from: rawOutput)
                    )
                )
                print("Sample \(sample.id): \(String(format: "%.3f", latencySeconds))s")
            }
            let benchmarkSeconds = Date().timeIntervalSince(benchmarkStart)

            return MLXSteadyBenchmarkResult.completed(
                manifestPath: options.manifestPathForOutput,
                maxTokens: options.maxTokens,
                loadSeconds: loadSeconds,
                warmupSeconds: warmupSeconds,
                benchmarkSeconds: benchmarkSeconds,
                samples: benchmarkSamples,
                notes: notes() + [
                    "Summary latency excludes one-time model load and one warmup generation.",
                    "Each sample latency includes prompt preparation plus generation for one cleanup call."
                ],
                swiftToolchain: swiftToolchain,
                machineContext: machineContext
            )
        } catch {
            return MLXSteadyBenchmarkResult.blocked(
                status: .generationFailed,
                manifestPath: options.manifestPathForOutput,
                maxTokens: options.maxTokens,
                blocker: String(describing: error),
                notes: notes(),
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

    private static func cleanupPrompt(reference: String) -> String {
        """
        Clean this dictated text. Preserve meaning. Remove only obvious filler, false starts, and stutter repetitions. Fix punctuation and capitalization. Return only the cleaned text.

        Input: \(reference)
        """
    }

    private static func cleanupCandidate(from rawOutput: String) -> String {
        rawOutput
            .replacingOccurrences(of: "Output:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func writeBlockedResult(
        options: BenchmarkOptions,
        status: MLXSteadyBenchmarkStatus,
        blocker: String
    ) {
        let result = MLXSteadyBenchmarkResult.blocked(
            status: status,
            manifestPath: options.manifestPathForOutput,
            maxTokens: options.maxTokens,
            blocker: blocker,
            notes: notes(),
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

    private static func write(_ result: MLXSteadyBenchmarkResult, to outputURL: URL) throws {
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.localFlowSpike.encode(result)
        try data.write(to: outputURL, options: .atomic)
    }

    private static func notes() -> [String] {
        [
            "Native Swift package path; no oMLX app, Ollama server, or Python helper.",
            "Target model is the approved 4-bit MLX Hugging Face artifact.",
            "Benchmark loads the model once, performs one warmup, then runs repeated cleanup calls in one process."
        ]
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

private struct BenchmarkOptions {
    let outputURL: URL
    let manifestURL: URL
    let maxTokens: Int
    let limit: Int?
    let workerMode: Bool

    var manifestPathForOutput: String {
        manifestURL.path
    }

    static func parse(_ arguments: [String]) throws -> BenchmarkOptions {
        var outputURL = defaultOutputURL()
        var manifestURL = defaultManifestURL()
        var maxTokens = 80
        var limit: Int?
        var workerMode = false
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--worker":
                workerMode = true
            case "--output":
                outputURL = URL(fileURLWithPath: try value(after: argument, in: arguments, at: &index))
            case "--manifest":
                manifestURL = URL(fileURLWithPath: try value(after: argument, in: arguments, at: &index))
            case "--max-tokens":
                let raw = try value(after: argument, in: arguments, at: &index)
                guard let parsed = Int(raw), parsed > 0 else {
                    throw BenchmarkCLIError.invalidValue(argument, raw)
                }
                maxTokens = parsed
            case "--limit":
                let raw = try value(after: argument, in: arguments, at: &index)
                guard let parsed = Int(raw), parsed > 0 else {
                    throw BenchmarkCLIError.invalidValue(argument, raw)
                }
                limit = parsed
            case "--help", "-h":
                throw BenchmarkCLIError.helpRequested
            default:
                throw BenchmarkCLIError.unknownArgument(argument)
            }
            index += 1
        }

        return BenchmarkOptions(
            outputURL: outputURL,
            manifestURL: manifestURL,
            maxTokens: maxTokens,
            limit: limit,
            workerMode: workerMode
        )
    }

    func workerArguments(outputURL: URL) -> [String] {
        var arguments = [
            "--worker",
            "--output", outputURL.path,
            "--manifest", manifestURL.path,
            "--max-tokens", String(maxTokens)
        ]
        if let limit {
            arguments.append(contentsOf: ["--limit", String(limit)])
        }
        return arguments
    }

    private static func defaultOutputURL() -> URL {
        let current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let repositoryRoot = current.lastPathComponent == "bench" ? current.deletingLastPathComponent() : current
        return repositoryRoot
            .appendingPathComponent("docs")
            .appendingPathComponent("reports")
            .appendingPathComponent("mlx-cleanup-benchmark")
            .appendingPathComponent("runs")
            .appendingPathComponent("2026-07-06-task-5-swift-steady-state-cleanup")
            .appendingPathComponent("swift-steady-benchmark.json")
    }

    private static func defaultManifestURL() -> URL {
        let current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        if current.lastPathComponent == "bench" {
            return current.appendingPathComponent("samples").appendingPathComponent("manifest.json")
        }
        return current.appendingPathComponent("bench").appendingPathComponent("samples").appendingPathComponent("manifest.json")
    }

    private static func value(after argument: String, in arguments: [String], at index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw BenchmarkCLIError.missingValue(argument)
        }
        index = valueIndex
        return arguments[valueIndex]
    }
}

private enum BenchmarkCLIError: LocalizedError {
    case helpRequested
    case invalidValue(String, String)
    case missingValue(String)
    case unknownArgument(String)

    var errorDescription: String? {
        switch self {
        case .helpRequested:
            return """
            Usage: mlx-cleanup-steady-benchmark [--output PATH] [--manifest PATH] [--max-tokens COUNT] [--limit COUNT]
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

private struct BenchmarkManifest: Decodable {
    let samples: [BenchmarkSample]

    static func load(from url: URL) throws -> BenchmarkManifest {
        try JSONDecoder().decode(BenchmarkManifest.self, from: Data(contentsOf: url))
    }

    func samplesForRun(limit: Int?) -> [BenchmarkSample] {
        guard let limit else {
            return samples
        }
        return Array(samples.prefix(limit))
    }
}

private struct BenchmarkSample: Decodable {
    let id: String
    let file: String
    let reference: String
}
