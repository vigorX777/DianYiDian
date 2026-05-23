// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DianYiDian",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DianYiDian", targets: ["DianYiDian"]),
        .executable(name: "DianYiDianCoreChecks", targets: ["DianYiDianCoreChecks"]),
        .library(name: "DianYiDianCore", targets: ["DianYiDianCore"])
    ],
    targets: [
        .target(
            name: "DianYiDianCore",
            path: "Sources/DianYiDianCore"
        ),
        .executableTarget(
            name: "DianYiDian",
            dependencies: ["DianYiDianCore"],
            path: "Sources/DianYiDian",
            resources: [
                .copy("Resources")
            ]
        ),
        .executableTarget(
            name: "DianYiDianCoreChecks",
            dependencies: ["DianYiDianCore"],
            path: "Checks/DianYiDianCoreChecks"
        )
    ]
)
