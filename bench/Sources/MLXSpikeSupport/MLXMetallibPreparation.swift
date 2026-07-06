import Foundation

public struct MetalToolchainComponent: Decodable, Equatable {
    public let status: String
    public let toolchainIdentifier: String?
    public let toolchainSearchPath: String?

    public var metalCompilerURL: URL {
        URL(fileURLWithPath: toolchainSearchPath ?? "")
            .appendingPathComponent("Metal.xctoolchain")
            .appendingPathComponent("usr")
            .appendingPathComponent("bin")
            .appendingPathComponent("metal")
    }

    public static func installed(from data: Data) throws -> MetalToolchainComponent {
        let component: MetalToolchainComponent
        do {
            component = try JSONDecoder().decode(MetalToolchainComponent.self, from: data)
        } catch {
            throw MLXMetallibPreparationError.invalidToolchainJSON(String(describing: error))
        }

        guard component.status == "installed" else {
            throw MLXMetallibPreparationError.metalToolchainNotInstalled(status: component.status)
        }

        guard let path = component.toolchainSearchPath, !path.isEmpty else {
            throw MLXMetallibPreparationError.missingToolchainSearchPath
        }

        return component
    }
}

public struct MLXMetallibLayout: Equatable {
    public let packageRoot: URL
    public let outputDirectory: URL

    public init(packageRoot: URL, outputDirectory: URL) {
        self.packageRoot = packageRoot.standardizedFileURL
        self.outputDirectory = outputDirectory.standardizedFileURL
    }

    public var checkoutRoot: URL {
        packageRoot
            .appendingPathComponent(".build")
            .appendingPathComponent("checkouts")
            .appendingPathComponent("mlx-swift")
    }

    public var sourceRoot: URL {
        checkoutRoot
            .appendingPathComponent("Source")
            .appendingPathComponent("Cmlx")
            .appendingPathComponent("mlx")
    }

    public var kernelDirectory: URL {
        sourceRoot
            .appendingPathComponent("mlx")
            .appendingPathComponent("backend")
            .appendingPathComponent("metal")
            .appendingPathComponent("kernels")
    }

    public var outputURL: URL {
        outputDirectory.appendingPathComponent("mlx.metallib")
    }
}

public struct MetalCompilePlan: Equatable {
    public let executableURL: URL
    public let arguments: [String]
    public let outputURL: URL
}

public enum MLXMetallibPreparationError: Error, CustomStringConvertible, Equatable {
    case invalidToolchainJSON(String)
    case metalToolchainNotInstalled(status: String)
    case missingToolchainSearchPath
    case missingMetalCompiler(URL)
    case missingMLXCheckout(URL)
    case missingKernelDirectory(URL)
    case noMetalSources(URL)
    case missingRuntimeMetallib(URL)
    case failedToCreateOutputDirectory(URL, String)
    case metalCompilerFailed(exitStatus: Int32, output: String)

    public var description: String {
        switch self {
        case .invalidToolchainJSON(let detail):
            return "Could not parse `xcodebuild -showComponent MetalToolchain -json` output: \(detail)"
        case .metalToolchainNotInstalled(let status):
            return "MetalToolchain is not installed (status: \(status)). Run `xcodebuild -downloadComponent MetalToolchain`, then retry."
        case .missingToolchainSearchPath:
            return "`xcodebuild -showComponent MetalToolchain -json` did not include `toolchainSearchPath`."
        case .missingMetalCompiler(let url):
            return "Metal compiler was not found at \(url.path). Re-run `xcodebuild -downloadComponent MetalToolchain`."
        case .missingMLXCheckout(let url):
            return "MLX Swift checkout was not found at \(url.path). Run `swift package resolve` from `bench/` first."
        case .missingKernelDirectory(let url):
            return "MLX Metal kernel directory was not found at \(url.path). The mlx-swift package layout may have changed."
        case .noMetalSources(let url):
            return "No `.metal` sources were found under \(url.path). The metallib cannot be built."
        case .missingRuntimeMetallib(let url):
            return "Runtime metallib was not found at \(url.path). Run `swift run mlx-metallib-prepare` from `bench/`, then retry."
        case .failedToCreateOutputDirectory(let url, let detail):
            return "Could not create metallib output directory \(url.path): \(detail)"
        case .metalCompilerFailed(let exitStatus, let output):
            return "Metal compiler failed with exit status \(exitStatus): \(output)"
        }
    }
}

public enum MLXMetallibRuntime {
    public static func metallibURL(nextToExecutable executableURL: URL) -> URL {
        executableURL
            .deletingLastPathComponent()
            .appendingPathComponent("mlx.metallib")
    }

    public static func validateAvailable(
        nextToExecutable executableURL: URL,
        fileManager: FileManager = .default
    ) throws {
        let metallibURL = metallibURL(nextToExecutable: executableURL)
        guard fileManager.fileExists(atPath: metallibURL.path) else {
            throw MLXMetallibPreparationError.missingRuntimeMetallib(metallibURL)
        }
    }
}

public enum MLXMetallibPreparer {
    public static func discoverMetalSources(
        in kernelDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> [URL] {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: kernelDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw MLXMetallibPreparationError.missingKernelDirectory(kernelDirectory)
        }

        guard let enumerator = fileManager.enumerator(
            at: kernelDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw MLXMetallibPreparationError.missingKernelDirectory(kernelDirectory)
        }

        let sources = enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "metal" }
            .sorted(by: stableSourceSort)

        guard !sources.isEmpty else {
            throw MLXMetallibPreparationError.noMetalSources(kernelDirectory)
        }

        return sources
    }

    public static func validateLayout(_ layout: MLXMetallibLayout, fileManager: FileManager = .default) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: layout.checkoutRoot.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw MLXMetallibPreparationError.missingMLXCheckout(layout.checkoutRoot)
        }

        guard fileManager.fileExists(atPath: layout.kernelDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw MLXMetallibPreparationError.missingKernelDirectory(layout.kernelDirectory)
        }
    }

    public static func validateCompiler(_ compilerURL: URL, fileManager: FileManager = .default) throws {
        guard fileManager.isExecutableFile(atPath: compilerURL.path) else {
            throw MLXMetallibPreparationError.missingMetalCompiler(compilerURL)
        }
    }

    public static func compilePlan(
        compilerURL: URL,
        layout: MLXMetallibLayout,
        metalSources: [URL]
    ) -> MetalCompilePlan {
        let orderedSources = metalSources.sorted(by: stableSourceSort)
        var arguments = [
            "-Wall",
            "-Wextra",
            "-fno-fast-math",
            "-Wno-c++17-extensions",
            "-I",
            layout.sourceRoot.path,
            "-I",
            layout.kernelDirectory.path
        ]
        arguments.append(contentsOf: orderedSources.map(\.path))
        arguments.append(contentsOf: ["-o", layout.outputURL.path])

        return MetalCompilePlan(
            executableURL: compilerURL,
            arguments: arguments,
            outputURL: layout.outputURL
        )
    }

    public static func createOutputDirectory(for layout: MLXMetallibLayout, fileManager: FileManager = .default) throws {
        do {
            try fileManager.createDirectory(at: layout.outputDirectory, withIntermediateDirectories: true)
        } catch {
            throw MLXMetallibPreparationError.failedToCreateOutputDirectory(
                layout.outputDirectory,
                String(describing: error)
            )
        }
    }

    private static func stableSourceSort(_ lhs: URL, _ rhs: URL) -> Bool {
        if lhs.lastPathComponent == rhs.lastPathComponent {
            return lhs.path < rhs.path
        }
        return lhs.lastPathComponent < rhs.lastPathComponent
    }
}
