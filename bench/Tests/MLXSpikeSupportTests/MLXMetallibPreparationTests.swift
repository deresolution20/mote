import Foundation
import Testing
@testable import MLXSpikeSupport

@Suite struct MLXMetallibPreparationTests {
    @Test func parsesInstalledMetalToolchainComponent() throws {
        let json = """
        {
          "status": "installed",
          "toolchainIdentifier": "com.apple.dt.toolchain.Metal.32023.883",
          "toolchainSearchPath": "/private/var/run/com.apple.security.cryptexd/mnt/com.apple.MobileAsset.MetalToolchain-v17.6.109.0.Y9Y3BE"
        }
        """.data(using: .utf8)!

        let component = try MetalToolchainComponent.installed(from: json)

        #expect(component.status == "installed")
        #expect(component.toolchainIdentifier == "com.apple.dt.toolchain.Metal.32023.883")
        #expect(component.metalCompilerURL.path.hasSuffix("/Metal.xctoolchain/usr/bin/metal"))
    }

    @Test func rejectsUnavailableMetalToolchainWithActionableMessage() throws {
        let json = """
        {
          "status": "downloadable",
          "toolchainIdentifier": "com.apple.dt.toolchain.Metal.32023.883"
        }
        """.data(using: .utf8)!

        do {
            _ = try MetalToolchainComponent.installed(from: json)
            Issue.record("Expected unavailable Metal toolchain to be rejected.")
        } catch let error as MLXMetallibPreparationError {
            #expect(error.description.contains("MetalToolchain is not installed"))
            #expect(error.description.contains("xcodebuild -downloadComponent MetalToolchain"))
        }
    }

    @Test func discoversMetalSourcesInDeterministicOrder() throws {
        let root = try TemporaryDirectory()
        let kernels = root.url.appendingPathComponent("kernels")
        let nested = kernels.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data().write(to: kernels.appendingPathComponent("z_last.metal"))
        try Data().write(to: kernels.appendingPathComponent("a_first.metal"))
        try Data().write(to: nested.appendingPathComponent("m_nested.metal"))
        try Data().write(to: kernels.appendingPathComponent("ignored.txt"))

        let sources = try MLXMetallibPreparer.discoverMetalSources(in: kernels)

        #expect(sources.map(\.lastPathComponent) == [
            "a_first.metal",
            "m_nested.metal",
            "z_last.metal"
        ])
    }

    @Test func buildsMetalCompilePlanWithIncludesSourcesAndOutput() throws {
        let packageRoot = URL(fileURLWithPath: "/tmp/local-flow/bench", isDirectory: true)
        let outputDirectory = URL(fileURLWithPath: "/tmp/local-flow/bench/.build/arm64-apple-macosx/debug", isDirectory: true)
        let layout = MLXMetallibLayout(packageRoot: packageRoot, outputDirectory: outputDirectory)
        let compilerURL = URL(fileURLWithPath: "/tmp/Metal.xctoolchain/usr/bin/metal")
        let firstSource = layout.kernelDirectory.appendingPathComponent("a.metal")
        let secondSource = layout.kernelDirectory.appendingPathComponent("nested/b.metal")

        let plan = MLXMetallibPreparer.compilePlan(
            compilerURL: compilerURL,
            layout: layout,
            metalSources: [secondSource, firstSource]
        )

        #expect(plan.executableURL == compilerURL)
        #expect(plan.outputURL == outputDirectory.appendingPathComponent("mlx.metallib"))
        #expect(plan.arguments.prefix(8) == [
            "-Wall",
            "-Wextra",
            "-fno-fast-math",
            "-Wno-c++17-extensions",
            "-I",
            layout.sourceRoot.path,
            "-I",
            layout.kernelDirectory.path
        ])
        #expect(plan.arguments.suffix(2) == ["-o", plan.outputURL.path])
        #expect(plan.arguments.contains(firstSource.path))
        #expect(plan.arguments.contains(secondSource.path))
        #expect(plan.arguments.firstIndex(of: firstSource.path)! < plan.arguments.firstIndex(of: secondSource.path)!)
    }

    @Test func runtimePreflightChecksForMetallibNextToExecutable() throws {
        let root = try TemporaryDirectory()
        let executableURL = root.url
            .appendingPathComponent("debug")
            .appendingPathComponent("mlx-cleanup-spike")
        let expectedMetallibURL = executableURL
            .deletingLastPathComponent()
            .appendingPathComponent("mlx.metallib")

        #expect(MLXMetallibRuntime.metallibURL(nextToExecutable: executableURL) == expectedMetallibURL)

        do {
            try MLXMetallibRuntime.validateAvailable(nextToExecutable: executableURL)
            Issue.record("Expected missing runtime metallib to be rejected.")
        } catch let error as MLXMetallibPreparationError {
            #expect(error.description.contains(expectedMetallibURL.path))
            #expect(error.description.contains("swift run mlx-metallib-prepare"))
        }
    }
}

private struct TemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("local-flow-tests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
