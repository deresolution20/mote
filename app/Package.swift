// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LocalFlow",
    platforms: [
        .macOS("26.0")
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.15.0"),
    ],
    targets: [
        .executableTarget(
            name: "LocalFlow",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio"),
            ],
            path: "Sources/LocalFlow"
        ),
    ]
)
