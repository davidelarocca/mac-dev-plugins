// swift-tools-version: 6.0
// Compiles the design-system reference files shipped with the plugin
// (symlinked from plugins/swift-harness/skills/design-system/references/).
// CI builds it with tests: an example that stops compiling fails the build.
import PackageDescription

let package = Package(
    name: "DesignSystem",
    platforms: [.macOS(.v14)],
    products: [.library(name: "DesignSystem", targets: ["DesignSystem"])],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),
    ],
    targets: [
        .target(name: "DesignSystem", resources: [.process("Resources")]),
        .testTarget(
            name: "DesignSystemTests",
            dependencies: [
                "DesignSystem",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ]
)
