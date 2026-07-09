// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LocalFlow",
    platforms: [
        .macOS("26.0")
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.15.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", .upToNextMajor(from: "3.31.4")),
        .package(url: "https://github.com/huggingface/swift-huggingface", from: "0.9.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "LocalFlowCleanup",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "Tokenizers", package: "swift-transformers"),
            ],
            path: "Sources/LocalFlowCleanup"
        ),
        .executableTarget(
            name: "LocalFlow",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio"),
                "LocalFlowCleanup",
            ],
            path: "Sources/LocalFlow"
        ),
        .executableTarget(
            name: "local-flow-cleanup-acceptance",
            dependencies: ["LocalFlowCleanup"],
            path: "Sources/LocalFlowCleanupAcceptance"
        ),
        .testTarget(
            name: "LocalFlowTests",
            dependencies: ["LocalFlowCleanup", "LocalFlow"],
            path: "Tests/LocalFlowTests"
        ),
    ]
)
