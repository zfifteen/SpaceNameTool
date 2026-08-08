// swift-tools-version: 5.9
// SpaceNameTool — SIP-safe macOS menu-bar app for naming virtual desktops (Spaces).
//
// HARD constraints:
// - Full System Integrity Protection stays enabled.
// - No code injection into Dock, WindowServer, or any system process.
// - No csrutil, LaunchDaemon, or privileged helper.
// - CGS/SkyLight only via dlsym; degrade if symbols disappear.

import PackageDescription

let package = Package(
    name: "SpaceNameTool",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "SpaceNameToolCore", targets: ["SpaceNameToolCore"]),
        .executable(name: "SpaceNameTool", targets: ["SpaceNameTool"])
    ],
    targets: [
        .target(
            name: "SpaceNameToolCore",
            path: "Sources/SpaceNameToolCore"
        ),
        .executableTarget(
            name: "SpaceNameTool",
            dependencies: ["SpaceNameToolCore"],
            path: "Sources/SpaceNameTool"
        ),
        .testTarget(
            name: "SpaceNameToolTests",
            dependencies: ["SpaceNameToolCore"],
            path: "Tests/SpaceNameToolTests"
        )
    ]
)
