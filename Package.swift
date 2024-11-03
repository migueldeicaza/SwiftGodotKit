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
        //.package(url: "https://github.com/migueldeicaza/SwiftGodot", revision: "fe24cb01640c2d4d48c8555a71adfe346d9543cf")
        .package(path: "../SwiftGodot"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftGodotKit",
            dependencies: [
                "SwiftGodot",
                .target(name: "mac_libgodot", condition: .when(platforms: [.macOS])),
                .target(name: "ios_libgodot", condition: .when(platforms: [.iOS])),
                .target(name: "MoltenVK", condition: .when(platforms: [.iOS])),
                .target(name: "libgodot", condition: .when(platforms: [.linux, .windows])),
            ]
        ),
        
        .executableTarget(
            name: "UglySample",
            dependencies: ["SwiftGodotKit"]
        ),
        
        .executableTarget(
            name: "TrivialSample",
            dependencies: ["SwiftGodotKit"],
            
            // This line does not seem to do anything in Xcode, so you need to manually
            // copy main.pck and make it available from somwehere else
            resources: [.copy("main.pck")]
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
                .target(name: "mac_libgodot", condition: .when(platforms: [.macOS])),
                .target(name: "ios_libgodot", condition: .when(platforms: [.iOS])),
                .target(name: "libgodot", condition: .when(platforms: [.linux, .windows])),
            ],
            resources: [.copy ("Project")]
        ),
        .binaryTarget(name: "MoltenVK", path: "scripts/MoltenVK.xcframework"),
        .binaryTarget(name: "mac_libgodot",
                      path: "scripts/libgodot.xcframework"),
        .binaryTarget(name: "ios_libgodot",
                      path: "scripts/ios/libgodot.xcframework"),

//        .binaryTarget (
//            name: "binary_libgodot",
//            url: "https://github.com/migueldeicaza/SwiftGodotKit/releases/download/p4_3-1.0.1/libgodot.xcframework.zip",
//            checksum: "da73a96dc044e7b4feb464bd99f9fbb21d55bcf1f7f4e609690bd85ce3043bc6"
//        ),
        .systemLibrary(
            name: "libgodot"
        ),
    ]
)
