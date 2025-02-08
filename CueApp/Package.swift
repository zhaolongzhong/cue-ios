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
        .package(path: "../CueAnthropic"),
        .package(path: "../CueMCP"),
        .package(path: "../CueCommon"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.29.1"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.6.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.4"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "CueApp",
            dependencies: [
                .product(name: "CueCommon", package: "CueCommon"),
                .product(name: "CueOpenAI", package: "CueOpenAI"),
                .product(name: "CueAnthropic", package: "CueAnthropic"),
                .product(name: "CueMCP", package: "CueMCP"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(
                    name: "Sparkle",
                    package: "Sparkle",
                    condition: .when(platforms: [.macOS])
                ),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                .product(name: "GoogleSignInSwift", package: "GoogleSignIn-iOS")
            ],
            path: "Sources/CueApp",
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "CueAppTests",
            dependencies: ["CueApp"],
            path: "Tests/CueAppTests")
    ]
)
