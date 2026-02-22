// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StandaloneExample",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .executable(
            name: "StandaloneExample",
            targets: ["StandaloneExample"]),
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftGodot", revision: "48112dd50fffe01f0af78e445a16991ecdc6bc94"),
        .package(url: "https://github.com/migueldeicaza/SwiftGodotKit", revision: "d4205c6a27754f037291cce54030786916b8e79a")
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
