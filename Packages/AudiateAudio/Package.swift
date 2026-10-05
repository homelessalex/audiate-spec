// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AudiateAudio",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AudiateAudio", targets: ["AudiateAudio"]),
    ],
    dependencies: [
        .package(path: "../AudiateCore"),
    ],
    targets: [
        .target(name: "AudiateAudio", dependencies: ["AudiateCore"]),
        .testTarget(name: "AudiateAudioTests", dependencies: ["AudiateAudio"]),
    ]
)
