// swift-tools-version:6.0
// Layout contract fixture (#34): screens that break at their minimum size, and the
// LayoutContract helper from the setup templates (linked into the test target) catching it.
import PackageDescription

let package = Package(
    name: "LayoutFixture",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "Screens"),
        .testTarget(name: "ScreensTests", dependencies: ["Screens"]),
    ]
)
