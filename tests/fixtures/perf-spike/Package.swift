// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "Work", platforms: [.macOS(.v14)],
  targets: [.target(name: "Work"), .testTarget(name: "WorkTests", dependencies: ["Work"])])
