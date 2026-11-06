// swift-tools-version:6.0
// Screenshot review fixture (#35): two screens drawn only with tokens, with defects that show
// in the rendered UI and not in the code, and the Screenshot helper from the setup templates
// (linked into the test target) capturing them.
import PackageDescription

let package = Package(
    name: "VisualFixture",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "Screens"),
        .testTarget(name: "ScreensTests", dependencies: ["Screens"]),
    ]
)
