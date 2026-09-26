// swift-tools-version: 5.9
import PackageDescription
let macLibgodotTarget: Target = .binaryTarget(
    name: "mac_libgodot",
    url: "https://github.com/migueldeicaza/godot/releases/download/v4.6.5/libgodot-macos.xcframework.zip",
    checksum: "e3768a09b3bd0ecbc5024912da5d133d68d81b7087e508f897255da79f041af9"
)

let iosLibgodotTarget: Target = .binaryTarget(
    name: "ios_libgodot",
    url: "https://github.com/migueldeicaza/godot/releases/download/v4.6.5/libgodot-ios.xcframework.zip",
    checksum: "ce0dc9fc83afbca3d0860742de8fc2fa7db540d185c239dc6dde4969c62978e3"
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
        // This revision is tag 0.75.0.
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

        .testTarget(
            name: "SwiftGodotKitTests",
            dependencies: ["SwiftGodotKit"]
        ),

        macLibgodotTarget,
        iosLibgodotTarget,
        .systemLibrary(
            name: "libgodot"
        ),
    ]
)
