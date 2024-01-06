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
        .executable(name: "Dodge", targets: ["Dodge"]),
        .executable(name: "UglySample", targets: ["UglySample"]),
        .executable(name: "Properties", targets: ["Properties"]),
        .executable(name: "TrivialSample", targets: ["TrivialSample"]),
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftGodot", revision: "7c932b45b6683b4d1307d67a5969a65a5ce2ad3d")
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

            .executableTarget(
                name: "Properties",
                dependencies: ["SwiftGodotKit"]),
        
        // This is a sample that I am porting
        .target(
            name: "Dodge",
            dependencies: ["SwiftGodotKit", "libgodot"]),
        .binaryTarget (
            name: "libgodot",
            url: "https://github.com/migueldeicaza/SwiftGodotKit/releases/download/v1.0.1/libgodot.xcframework.zip",
            checksum: "bb6ec0946311a71f1eba7ad393c0adf7b8f34a2389d8234ff500b2764b0c6ba5"
        ),
        .testTarget(
            name: "SwiftGodotKitTests",
            dependencies: ["SwiftGodotKit"]),
    ]
)
