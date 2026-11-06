// swift-tools-version:6.0
// Screenshot review fixture (#35): two screens drawn only with tokens, with layout defects that
// the rendered UI shows plainly (a careful code review can infer them), and the Screenshot
// helper from the setup templates (linked into the test target) capturing them.
import PackageDescription

let package = Package(
    name: "VisualFixture",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "Screens"),
        .testTarget(name: "ScreensTests", dependencies: ["Screens"]),
    ]
)
