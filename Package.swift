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
        .library(name: "Dodge", targets: ["Dodge"]),
        .executable(name: "UglySample", targets: ["UglySample"]),
        .executable(name: "TrivialSample", targets: ["TrivialSample"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftGodot", revision: "0bdd4fe1336c552f991291a04d2c93fb5730cd5a")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftGodotKit",
            dependencies: ["SwiftGodot", "libgodot"]),
        
        .executableTarget(
            name: "UglySample",
            dependencies: ["SwiftGodotKit"]),

            .executableTarget(
            name: "TrivialSample",
            dependencies: ["SwiftGodotKit"]),


        // This is a sample that I am porting
        .target(
            name: "Dodge",
            dependencies: ["SwiftGodotKit", "libgodot"]),
        .binaryTarget (
            name: "libgodot",
            url: "https://github.com/migueldeicaza/SwiftGodotKit/releases/download/v1.0.0/libgodot.xcframework.zip",
            checksum: "bbe8f4225c34187e5d9b183a60147826a79e7f40e43b47b6ed98b311b6242a6d"
        ),
        .testTarget(
            name: "SwiftGodotKitTests",
            dependencies: ["SwiftGodotKit"]),
    ]
)
