// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MacLauncher",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacLauncher", targets: ["MacLauncher"])
    ],
    targets: [
        .executableTarget(
            name: "MacLauncher",
            path: "Sources/MacLauncher"
        )
    ]
)

