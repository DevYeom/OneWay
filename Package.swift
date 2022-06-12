// swift-tools-version: 5.5

import PackageDescription

let package = Package(
    name: "OneWay",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(
            name: "OneWay",
            targets: ["OneWay"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "OneWay",
            dependencies: []
        ),
        .testTarget(
            name: "OneWayTests",
            dependencies: ["OneWay"]
        ),
    ]
)
