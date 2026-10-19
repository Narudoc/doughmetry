// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DoughmetryCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DoughmetryCore", targets: ["DoughmetryCore"])
    ],
    targets: [
        .target(name: "DoughmetryCore"),
        .executableTarget(name: "doughmetry-core-check", dependencies: ["DoughmetryCore"]),
        .testTarget(name: "DoughmetryCoreTests", dependencies: ["DoughmetryCore"]),
    ]
)
