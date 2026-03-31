// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "sws",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "sws",
            path: "Sources/sws",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
            ]
        ),
    ]
)
