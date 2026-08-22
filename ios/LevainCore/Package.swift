// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LevainCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LevainCore", targets: ["LevainCore"])
    ],
    targets: [
        .target(name: "LevainCore"),
        .executableTarget(name: "levain-core-check", dependencies: ["LevainCore"]),
        .testTarget(name: "LevainCoreTests", dependencies: ["LevainCore"]),
    ]
)
