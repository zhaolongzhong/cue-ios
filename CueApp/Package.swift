// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CueApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CueApp",
            targets: ["CueApp"])
    ],
    dependencies: [
        .package(path: "../CueOpenAI"),
        // .package(url: "https://github.com/m1guelpf/swift-realtime-openai.git", branch: "main"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.29.1")
    ],
    targets: [
        .target(
            name: "CueApp",
            dependencies: [
                .product(name: "CueOpenAI", package: "CueOpenAI"),
                // .product(name: "OpenAI", package: "swift-realtime-openai"),
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources/CueApp"),
        .testTarget(
            name: "CueAppTests",
            dependencies: ["CueApp"],
            path: "Tests/CueAppTests")
    ]
)
