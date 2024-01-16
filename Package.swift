// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftGodotKit",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftGodotKit",
            targets: ["SwiftGodotKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftGodot", branch: "main")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftGodotKit",
            dependencies: ["SwiftGodot", "libgodot"]),
        .binaryTarget (
            name: "libgodot",
            url: "https://github.com/migueldeicaza/SwiftGodotKit/releases/download/v1.1.0/libgodot.xcframework.zip",
            checksum: "a90f2082714ac652c8aa6c1546a707c00a362b855071afa73a4443ffd96dcea0"
        )
    ]
)
