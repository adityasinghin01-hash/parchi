// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ParchiCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ParchiCore", targets: ["ParchiCore"]),
        .executable(name: "parchi-plan", targets: ["parchi-plan"]),
    ],
    targets: [
        .target(name: "ParchiCore"),
        .executableTarget(name: "parchi-plan", dependencies: ["ParchiCore"]),
        .testTarget(name: "ParchiCoreTests", dependencies: ["ParchiCore"]),
    ]
)
