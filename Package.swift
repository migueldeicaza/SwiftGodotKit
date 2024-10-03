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
        .package(url: "https://github.com/migueldeicaza/SwiftGodot", revision: "beb2928f404f2905674c5f85f37a63ea2c25eb76")
        //.package(path: "../SwiftGodot"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftGodotKit",
            dependencies: [
                "SwiftGodot",
                .target(name: "binary_libgodot", condition: .when(platforms: [.macOS])),
                .target(name: "libgodot", condition: .when(platforms: [.linux, .windows])),
            ]
        ),
        
        .executableTarget(
            name: "UglySample",
            dependencies: ["SwiftGodotKit"]
        ),
        
        .executableTarget(
            name: "TrivialSample",
            dependencies: ["SwiftGodotKit"]
        ),

        .executableTarget(
            name: "Properties",
            dependencies: ["SwiftGodotKit"]
        ),
        
        // This is a sample that I am porting
        .executableTarget(
            name: "Dodge",
            dependencies: [
                "SwiftGodotKit",
                .target(name: "binary_libgodot", condition: .when(platforms: [.macOS])),
                .target(name: "libgodot", condition: .when(platforms: [.linux, .windows])),
            ],
            resources: [.copy ("Project")]
        ),
        .binaryTarget (
            name: "binary_libgodot",
            url: "https://github.com/migueldeicaza/SwiftGodotKit/releases/download/4.3/libgodot.xcframework.zip",
            checksum: "aa73beb93b13dda88a9b983c1a134db8eb22723a7b022716b7a1d4782ffe9a49"
        ),
        .systemLibrary(
            name: "libgodot"
        ),
    ]
)
