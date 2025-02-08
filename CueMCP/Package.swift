// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CueMCP",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CueMCP",
            targets: ["CueMCP"]),
    ],
    dependencies: [
        .package(path: "../CueCommon")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CueMCP",
            dependencies: [
                .product(name: "CueCommon", package: "CueCommon")
            ]
        ),
        .testTarget(
            name: "CueMCPTests",
            dependencies: ["CueMCP"]
        ),
    ]
)
