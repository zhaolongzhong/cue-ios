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
        .package(url: "https://github.com/m1guelpf/swift-realtime-openai.git", branch: "main")
    ],
    targets: [
        .target(
            name: "CueApp",
            dependencies: [
                .product(name: "OpenAI", package: "swift-realtime-openai")
            ],
            path: "Sources/CueApp"),
        .testTarget(
            name: "CueAppTests",
            dependencies: ["CueApp"],
            path: "Tests/CueAppTests")
    ]
)
