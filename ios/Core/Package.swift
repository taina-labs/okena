// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OkenaCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "OkenaCore", targets: ["OkenaCore"])
    ],
    targets: [
        .target(name: "OkenaCore"),
        .testTarget(name: "OkenaCoreTests", dependencies: ["OkenaCore"]),
        .executableTarget(name: "okena-smoke", dependencies: ["OkenaCore"], path: "Smoke"),
    ]
)
