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
        .executable(name: "Properties", targets: ["Properties"]),
        .executable(name: "TrivialSample", targets: ["TrivialSample"]),
    ],
    dependencies: [
        .package(url: "https://github.com/EstevanBR/SwiftGodot", branch: "estevanBR")
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
//        .binaryTarget(name: "libgodot", path: "libgodot.xcframework"),
        .binaryTarget (
            name: "libgodot",
            url: "https://github.com/migueldeicaza/SwiftGodotKit/releases/download/v4.1.99/libgodot.xcframework.zip",
            checksum: "c8ddf62be6c00eacc36bd2dafe8d424c0b374833efe80546f6ee76bd27cee84e"
        ),
        .testTarget(
            name: "SwiftGodotKitTests",
            dependencies: ["SwiftGodotKit"]),
    ]
)
