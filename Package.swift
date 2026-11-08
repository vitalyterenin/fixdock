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
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")],
    targets: [
        .executableTarget(
            name: "Fixdock",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(name: "FixdockTests", dependencies: ["Fixdock"])
    ]
)
