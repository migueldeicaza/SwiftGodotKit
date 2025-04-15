// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftGodotKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v15)
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
        // The revision below points to my SwiftGodot on the "libgodot-4.3" branch
        //.package(url: "https://github.com/migueldeicaza/SwiftGodot", revision: "6ad577cd22c3ee1abb40d1f3727ad9e9f35d5aa2")
	.package(url: "https://github.com/migueldeicaza/SwiftGodot", revision: "7e4c34ccbc149cd61de3c8fa76a09f84bf5583f5")

	//        .package(path: "../../SwiftGodot"),
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
            ],
            resources: [.copy ("Project")]
        ),
        .binaryTarget (
            name: "binary_libgodot",
            url: "https://github.com/migueldeicaza/SwiftGodotKit/releases/download/4.3.5/libgodot.xcframework.zip",
            checksum: "865ea17ad3e20caab05b3beda35061f57143c4acf0e4ad2684ddafdcc6c4f199"
        ),
        .systemLibrary(
            name: "libgodot"
        ),
    ]
)
