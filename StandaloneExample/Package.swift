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
        .package(url: "https://github.com/migueldeicaza/SwiftGodot", revision: "f34e5796a517c104feb9a531a9814a826bda5b69"),
        .package(path: "..")
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
