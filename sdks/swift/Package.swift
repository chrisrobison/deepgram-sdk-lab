// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DeepgramSDKLab",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [.library(name: "DeepgramSDKLab", targets: ["DeepgramSDKLab"])],
    targets: [
        .target(name: "DeepgramSDKLab", path: "Sources/Deepgram"),
        .executableTarget(name: "deepgram-cli", dependencies: ["DeepgramSDKLab"], path: "Examples/CLI"),
        .executableTarget(name: "deepgram-bench", dependencies: ["DeepgramSDKLab"], path: "Benchmarks/Decode"),
        .testTarget(name: "DeepgramSDKLabTests", dependencies: ["DeepgramSDKLab"], path: "Tests/DeepgramTests")
    ]
)
