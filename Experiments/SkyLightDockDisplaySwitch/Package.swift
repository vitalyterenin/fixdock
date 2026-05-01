// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SkyLightDockDisplaySwitch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "SkyLightDockDisplaySwitch",
            targets: ["SkyLightDockDisplaySwitch"]
        )
    ],
    targets: [
        .executableTarget(
            name: "SkyLightDockDisplaySwitch",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices")
            ]
        )
    ]
)
