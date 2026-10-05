// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AudiateCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "AudiateCore", targets: ["AudiateCore"]),
    ],
    targets: [
        .target(name: "AudiateCore"),
        .testTarget(name: "AudiateCoreTests", dependencies: ["AudiateCore"]),
    ]
)
