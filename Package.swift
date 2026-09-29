// swift-tools-version: 5.9
import PackageDescription
let macLibgodotTarget: Target = .binaryTarget(
    name: "mac_libgodot",
    url: "https://github.com/migueldeicaza/godot/releases/download/v4.7.3-rc-swiftgodotkit.1/libgodot-macos.xcframework.zip",
    checksum: "dda4992c4c5abc8de7af49c3a1465e966aed74b3c0599c48544a333b9a94589e"
)

let iosLibgodotTarget: Target = .binaryTarget(
    name: "ios_libgodot",
    url: "https://github.com/migueldeicaza/godot/releases/download/v4.7.3-rc-swiftgodotkit.1/libgodot-ios.xcframework.zip",
    checksum: "20610e7d5c52302481a51e9fc020fd68a6b113e9ad19e2c5e602ab5d1c330f37"
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
        .package(url: "https://github.com/migueldeicaza/SwiftGodot", revision: "c3303eadffe4413eaab359983ff7cd759fd7f351"),
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
            resources: [
                .copy("main.pck"),
                .copy("AxolotlDemo-LICENSE.txt"),
                .copy("THIRD_PARTY.md"),
                .copy("Xolonium-OFL.txt"),
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
