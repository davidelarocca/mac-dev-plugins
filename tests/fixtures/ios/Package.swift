// swift-tools-version:5.9
// A package for macOS and iOS, verified by the generated scripts/verify.sh on both (#40).
import PackageDescription

let package = Package(
    name: "Kit",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "Kit", targets: ["Kit"])],
    targets: [
        .target(name: "Kit"),
        .testTarget(name: "KitTests", dependencies: ["Kit"])
    ]
)
