// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "bench",
    platforms: [
        .macOS("26.0")
    ],
    dependencies: [
        // WhisperKit now lives inside argmax-oss-swift (the standalone repo was folded in, 2026-05)
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "1.0.0"),
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.15.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", .upToNextMajor(from: "3.31.4")),
        .package(url: "https://github.com/huggingface/swift-huggingface", from: "0.9.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "MLXSpikeSupport",
            path: "Sources/MLXSpikeSupport"
        ),
        .executableTarget(
            name: "bench",
            dependencies: [
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/bench"
        ),
        .executableTarget(
            name: "mlx-cleanup-spike",
            dependencies: [
                "MLXSpikeSupport",
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "Tokenizers", package: "swift-transformers"),
            ],
            path: "Sources/MLXCleanupSpike"
        ),
        .executableTarget(
            name: "mlx-cleanup-steady-benchmark",
            dependencies: [
                "MLXSpikeSupport",
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "Tokenizers", package: "swift-transformers"),
            ],
            path: "Sources/MLXCleanupSteadyBenchmark"
        ),
        .executableTarget(
            name: "mlx-metallib-prepare",
            dependencies: [
                "MLXSpikeSupport",
            ],
            path: "Sources/MLXMetallibPrepare"
        ),
        .testTarget(
            name: "benchTests",
            dependencies: ["bench"],
            path: "Tests/benchTests"
        ),
        .testTarget(
            name: "MLXSpikeSupportTests",
            dependencies: ["MLXSpikeSupport"],
            path: "Tests/MLXSpikeSupportTests"
        ),
    ]
)
