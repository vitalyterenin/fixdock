// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Fixdock",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Fixdock", targets: ["Fixdock"])
    ],
    targets: [
        .executableTarget(
            name: "Fixdock",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
