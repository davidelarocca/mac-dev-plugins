// swift-tools-version:6.0
// Keyboard fixture (#52): shared components with keyboard actions, one reachable only by pointer,
// and the KeyboardCheck helper from the setup templates (linked into the test target) pressing
// keys on them.
import PackageDescription

let package = Package(
    name: "KeyboardFixture",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "Components"),
        .testTarget(name: "ComponentsTests", dependencies: ["Components"]),
    ]
)
