// swift-tools-version: 5.9
import PackageDescription
let macLibgodotTarget: Target = .binaryTarget(
    name: "mac_libgodot",
    url: "https://github.com/migueldeicaza/godot/releases/download/v4.6.4/libgodot-macos.xcframework.zip",
    checksum: "239485f07b67723f9b6790788049401e9c1e4dbd955a80a6cf88c4569033b006"
)

let iosLibgodotTarget: Target = .binaryTarget(
    name: "ios_libgodot",
    url: "https://github.com/migueldeicaza/godot/releases/download/v4.6.4/libgodot-ios.xcframework.zip",
    checksum: "d9e078f6375a12e7a29579a5c65269c0e5bad80c5e48e6eb4c6e47068af9656a"
)

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
        .executable(name: "TrivialSample", targets: ["TrivialSample"]),
    ],
    dependencies: [
    		  // This is tag 0.75.0
        .package(url: "https://github.com/migueldeicaza/SwiftGodot", revision: "48112dd50fffe01f0af78e445a16991ecdc6bc94"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftGodotKit",
            dependencies: [
                "SwiftGodot",
                "libgodot",
                .target(name: "apple_plugin_stubs", condition: .when(platforms: [.iOS])),
                .target(name: "mac_libgodot", condition: .when(platforms: [.macOS])),
                .target(name: "ios_libgodot", condition: .when(platforms: [.iOS])),
            ]
        ),

        .executableTarget(
            name: "TrivialSample",
            dependencies: ["SwiftGodotKit"],
            
            // This line does not seem to do anything in Xcode, so you need to manually
            // copy main.pck and make it available from somwehere else
            resources: [
                .copy("main.pck"),
                .copy("main.tscn"),
                .copy("project.godot"),
                .copy(".godot"),
                .copy("godot"),
            ]
        ),

        .target(
            name: "apple_plugin_stubs",
            path: "Sources/apple_plugin_stubs",
            publicHeadersPath: "include"
        ),

        macLibgodotTarget,
        iosLibgodotTarget,
        .systemLibrary(
            name: "libgodot"
        ),
    ]
)
