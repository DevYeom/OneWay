// swift-tools-version: 5.9

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
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/combine-schedulers",
            from: "1.0.0"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-clocks",
            from: "1.0.0"
        ),
    ],
    targets: [
        .target(
            name: "OneWay",
            dependencies: []
        ),
        .testTarget(
            name: "OneWayTests",
            dependencies: [
                "OneWay",
                .product(
                    name: "CombineSchedulers",
                    package: "combine-schedulers"
                ),
                .product(
                    name: "Clocks",
                    package: "swift-clocks"
                ),
            ]
        ),
    ]
)
