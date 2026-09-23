// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DeepgramSDKLab",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [.library(name: "DeepgramSDKLab", targets: ["DeepgramSDKLab"])],
    targets: [
        .target(name: "DeepgramSDKLab", path: "sdks/swift/Sources/Deepgram"),
        .target(name: "DeepgramMicrophone", path: "sdks/swift/Sources/DeepgramMicrophone"),
        .executableTarget(name: "deepgram-cli", dependencies: ["DeepgramSDKLab", "DeepgramMicrophone"], path: "sdks/swift/Examples/CLI"),
        .executableTarget(name: "deepgram-voice-playground", dependencies: ["DeepgramSDKLab", "DeepgramMicrophone"], path: "sdks/swift/Examples/VoicePlayground"),
        .executableTarget(name: "deepgram-bench", dependencies: ["DeepgramSDKLab"], path: "sdks/swift/Benchmarks/Decode"),
        .testTarget(name: "DeepgramSDKLabTests", dependencies: ["DeepgramSDKLab"], path: "sdks/swift/Tests/DeepgramTests")
    ]
)
