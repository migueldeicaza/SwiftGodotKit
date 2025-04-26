// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftGodotKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftGodotKit",
            targets: ["SwiftGodotKit"]),
s
        .executable(name: "TrivialSample", targets: ["TrivialSample"]),
    ],
    dependencies: [
        // The revision below points to my SwiftGodot on the "main" branch after release 0.60.1
        .package(url: "https://github.com/migueldeicaza/SwiftGodot", revision: "20d2d7a35d2ad392ec556219ea004da14ab7c1d4")

        // Use this one to develop locally
        //.package(path: "../SwiftGodot"),
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
                //.target(name: "libgodot", condition: .when(platforms: [.linux, .windows])),
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
        // Release 0.60.1 payloads
        .binaryTarget(
            name: "MoltenVK",
            url: "https://github.com/migueldeicaza/SwiftGodotKit/releases/download/0.60.1/MoltenVK.xcframework.zip",
            checksum: "92b0d55469f924256502f96122f5becf54af8b1321c768f80a92581bb460a414"),
        .binaryTarget(
            name: "mac_libgodot",
            url: "https://github.com/migueldeicaza/SwiftGodotKit/releases/download/0.60.1/libgodot.xcframework.zip",
            checksum: "78ae957377d8c7c8dbc9e7a32799a054daa44dfa4e365ca45665596b3a02715a"),
        .binaryTarget(
            name: "ios_libgodot",
            url: "https://github.com/migueldeicaza/SwiftGodotKit/releases/download/0.60.1/maclibgodot.xcframework.zip",
            checksum: "3a15ba49071cf521b5378c4bbdfd43b1ffade8a30c875308ced186462cf9cab1"),


        // Use these for local developoment.
//        .binaryTarget(name: "MoltenVK", path: "build/MoltenVK.xcframework"),
//        .binaryTarget(name: "mac_libgodot",
//                      path: "build/mac/libgodot.xcframework"),
//        .binaryTarget(name: "ios_libgodot",
//                      path: "build/ios/libgodot.xcframework"),
//
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
