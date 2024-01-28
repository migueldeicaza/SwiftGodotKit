// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StandaloneExample",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .executable(
            name: "StandaloneExample",
            targets: ["StandaloneExample"]),
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftGodot", revision: "1359586f2332d500d30661158e062a0e9f97751c"),
        .package(url: "https://github.com/migueldeicaza/SwiftGodotKit", revision: "a7f90ce4fa3e20fa95b57f1d95704445e5844d3d")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "StandaloneExample", dependencies: ["SwiftGodot", "SwiftGodotKit"]),
        .testTarget(
            name: "StandaloneExampleTests",
            dependencies: ["StandaloneExample"]),
    ]
)
