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
    ],
    targets: [
        .executableTarget(
            name: "bench",
            dependencies: [
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/bench"
        ),
        .testTarget(
            name: "benchTests",
            dependencies: ["bench"],
            path: "Tests/benchTests"
        ),
    ]
)
