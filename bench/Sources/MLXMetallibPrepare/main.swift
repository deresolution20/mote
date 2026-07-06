import Foundation
import MLXSpikeSupport

@main
struct MLXMetallibPrepare {
    static func main() {
        do {
            let options = try PrepareOptions.parse(Array(CommandLine.arguments.dropFirst()))
            if options.showHelp {
                print(PrepareOptions.help)
                return
            }

            let result = try prepare(options: options)
            print("Metal compiler: \(result.compilerURL.path)")
            print("Metal source files: \(result.sourceCount)")
            print("Wrote: \(result.outputURL.path)")
        } catch let error as MLXMetallibPreparationError {
            fputs("ERROR: \(error.description)\n", stderr)
            exit(1)
        } catch let error as PrepareCLIError {
            fputs("ERROR: \(error.description)\n", stderr)
            exit(error.exitCode)
        } catch {
            fputs("ERROR: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func prepare(options: PrepareOptions) throws -> PreparationResult {
        let toolchainData = try capturedOutput(
            executableURL: URL(fileURLWithPath: "/usr/bin/xcodebuild"),
            arguments: ["-showComponent", "MetalToolchain", "-json"],
            failureLabel: "xcodebuild -showComponent MetalToolchain -json"
        )
        let component = try MetalToolchainComponent.installed(from: toolchainData)
        try MLXMetallibPreparer.validateCompiler(component.metalCompilerURL)

        let layout = MLXMetallibLayout(
            packageRoot: options.packageRoot,
            outputDirectory: options.outputDirectory
        )
        try MLXMetallibPreparer.validateLayout(layout)
        let sources = try MLXMetallibPreparer.discoverMetalSources(in: layout.kernelDirectory)
        let plan = MLXMetallibPreparer.compilePlan(
            compilerURL: component.metalCompilerURL,
            layout: layout,
            metalSources: sources
        )

        try MLXMetallibPreparer.createOutputDirectory(for: layout)
        try run(plan)

        return PreparationResult(
            compilerURL: component.metalCompilerURL,
            sourceCount: sources.count,
            outputURL: plan.outputURL
        )
    }

    private static func capturedOutput(
        executableURL: URL,
        arguments: [String],
        failureLabel: String
    ) throws -> Data {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw PrepareCLIError.commandLaunchFailed(failureLabel, String(describing: error))
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw PrepareCLIError.commandFailed(failureLabel, process.terminationStatus, output)
        }
        return data
    }

    private static func run(_ plan: MetalCompilePlan) throws {
        let process = Process()
        process.executableURL = plan.executableURL
        process.arguments = plan.arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw MLXMetallibPreparationError.metalCompilerFailed(
                exitStatus: -1,
                output: String(describing: error)
            )
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            throw MLXMetallibPreparationError.metalCompilerFailed(
                exitStatus: process.terminationStatus,
                output: output
            )
        }
    }
}

private struct PreparationResult {
    let compilerURL: URL
    let sourceCount: Int
    let outputURL: URL
}

private struct PrepareOptions {
    let packageRoot: URL
    let outputDirectory: URL
    let showHelp: Bool

    static let help = """
    Usage: mlx-metallib-prepare [--package-root PATH] [--output-dir PATH]

    Builds mlx.metallib from the SwiftPM mlx-swift checkout and writes it next to
    the SwiftPM executable directory by default.
    """

    static func parse(_ arguments: [String]) throws -> PrepareOptions {
        var packageRoot = defaultPackageRoot()
        var outputDirectory = defaultOutputDirectory()
        var showHelp = false
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--package-root":
                packageRoot = URL(fileURLWithPath: try value(after: argument, in: arguments, at: &index), isDirectory: true)
            case "--output-dir":
                outputDirectory = URL(fileURLWithPath: try value(after: argument, in: arguments, at: &index), isDirectory: true)
            case "--help", "-h":
                showHelp = true
            default:
                throw PrepareCLIError.unknownArgument(argument)
            }
            index += 1
        }

        return PrepareOptions(
            packageRoot: packageRoot,
            outputDirectory: outputDirectory,
            showHelp: showHelp
        )
    }

    private static func defaultPackageRoot() -> URL {
        let current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let currentPackage = current.appendingPathComponent("Package.swift")
        if FileManager.default.fileExists(atPath: currentPackage.path) {
            return current
        }

        let bench = current.appendingPathComponent("bench", isDirectory: true)
        let benchPackage = bench.appendingPathComponent("Package.swift")
        if FileManager.default.fileExists(atPath: benchPackage.path) {
            return bench
        }

        return current
    }

    private static func defaultOutputDirectory() -> URL {
        URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
    }

    private static func value(after argument: String, in arguments: [String], at index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw PrepareCLIError.missingValue(argument)
        }
        index = valueIndex
        return arguments[valueIndex]
    }
}

private enum PrepareCLIError: Error, CustomStringConvertible {
    case commandFailed(String, Int32, String)
    case commandLaunchFailed(String, String)
    case missingValue(String)
    case unknownArgument(String)

    var exitCode: Int32 {
        switch self {
        case .missingValue, .unknownArgument:
            return 64
        case .commandFailed, .commandLaunchFailed:
            return 1
        }
    }

    var description: String {
        switch self {
        case .commandFailed(let command, let status, let output):
            return "`\(command)` failed with exit status \(status): \(output)"
        case .commandLaunchFailed(let command, let detail):
            return "Could not launch `\(command)`: \(detail)"
        case .missingValue(let argument):
            return "\(argument) requires a value"
        case .unknownArgument(let argument):
            return "unknown argument '\(argument)'"
        }
    }
}
