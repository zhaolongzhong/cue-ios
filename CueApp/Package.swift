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
    targets: [
        .target(name: "Theme"),
        .target(
            name: "CueApp",
            dependencies: ["Theme"],
            path: "Sources/CueApp"),
        .testTarget(
            name: "CueAppTests",
            dependencies: ["CueApp"],
            path: "Tests/CueAppTests")
    ]
)
