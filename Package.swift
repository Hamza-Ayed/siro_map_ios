// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SiroMap",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "SiroMap",
            targets: ["SiroMap"]),
        .library(
            name: "IntaleqMaps",
            targets: ["SiroMap"]),
    ],
    targets: [
        .target(
            name: "SiroMap",
            dependencies: [],
            path: "Sources/IntaleqMaps"
        ),
        .testTarget(
            name: "SiroMapTests",
            dependencies: ["SiroMap"],
            path: "Tests/IntaleqMapsTests"
        )
    ]
)
