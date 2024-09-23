// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "OneWay",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .visionOS(.v1),
        .watchOS(.v6),
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

//for target in package.targets {
//    target.swiftSettings = target.swiftSettings ?? []
//    target.swiftSettings?.append(
//        .enableExperimentalFeature("StrictConcurrency")
//    )
//}
