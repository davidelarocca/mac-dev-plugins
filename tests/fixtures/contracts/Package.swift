// swift-tools-version: 6.0
// Fixture for the architecture contracts (#13): tests/run.sh copies it into a temporary
// repo and changes its dependencies. Only read with `swift package dump-package`, never built.
import PackageDescription

let package = Package(
    name: "Contracts",
    platforms: [.macOS(.v14)],
    products: [.library(name: "App", targets: ["App"])],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections", from: "1.1.0"),
    ],
    targets: [
        .target(name: "App", dependencies: ["Features", "DesignSystem"]),
        .target(name: "Features", dependencies: ["Domain", "DesignSystem", .target(name: "Services")]),
        .target(name: "Domain", dependencies: [.product(name: "Collections", package: "swift-collections")]),
        .target(name: "Services", dependencies: ["Domain"]),
        .target(name: "DesignSystem"),
        .testTarget(name: "AppTests", dependencies: ["App", "Domain"]),
    ]
)
