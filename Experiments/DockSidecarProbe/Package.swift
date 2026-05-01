// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DockSidecarProbe",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "DockSidecarProbe",
            targets: ["DockSidecarProbe"]
        )
    ],
    targets: [
        .executableTarget(
            name: "DockSidecarProbe"
        )
    ]
)
