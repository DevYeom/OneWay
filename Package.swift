// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OneWay",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .visionOS(.v1),
        .watchOS(.v9),
    ],
    products: [
        .library(
            name: "OneWay",
            targets: ["OneWay"]
        ),
        .library(
            name: "OneWayTesting",
            targets: ["OneWayTesting"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-clocks",
            from: "1.0.0"
        ),
    ],
    targets: [
        .target(
            name: "OneWay",
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .testTarget(
            name: "OneWayTests",
            dependencies: [
                "OneWay",
                "OneWayTesting",
                .product(
                    name: "Clocks",
                    package: "swift-clocks"
                ),
            ]
        ),
        .target(
            name: "OneWayTesting",
            dependencies: ["OneWay"]
        ),
        .testTarget(
            name: "OneWayTestingTests",
            dependencies: ["OneWayTesting"]
        ),
    ]
)
