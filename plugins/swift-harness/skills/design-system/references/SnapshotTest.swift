import AppKit
import SnapshotTesting
import SwiftUI
import Testing
@testable import DesignSystem

// Package.swift test target dependency:
// .product(name: "SnapshotTesting", package: "swift-snapshot-testing")

enum Appearance: String, CaseIterable, Sendable {
    case light, dark

    var name: NSAppearance.Name { self == .light ? .aqua : .darkAqua }
}

@MainActor
private func render(_ view: some View, size: CGSize, appearance: Appearance) -> NSView {
    let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
    host.frame = CGRect(origin: .zero, size: size)
    host.appearance = NSAppearance(named: appearance.name)
    return host
}

@MainActor
@Suite("PillView snapshots")
struct PillViewSnapshotTests {
    private let size = CGSize(width: 320, height: 60)

    @Test(arguments: Appearance.allCases)
    func kinds(appearance: Appearance) {
        let pills: [Pill] = [.info("Info"), .success("Added to library"), .warning("Low disk space"), .error("Import failed")]
        for pill in pills {
            assertSnapshot(
                of: render(PillView(pill: pill), size: size, appearance: appearance),
                as: .image(precision: 0.99, perceptualPrecision: 0.98),
                named: "\(pill.kind)-\(appearance.rawValue)"
            )
        }
    }

    @Test func longText() {
        let pill = Pill.success(String(repeating: "Very long album title ", count: 6))
        assertSnapshot(
            of: render(PillView(pill: pill), size: CGSize(width: 320, height: 90), appearance: .aqua),
            as: .image(precision: 0.99, perceptualPrecision: 0.98)
        )
    }
}

// PillCenter behavior is plain logic: test it without rendering.
@MainActor
@Suite("PillCenter")
struct PillCenterTests {
    @Test func queuesWhileShowing() {
        let center = PillCenter()
        center.show(.info("First"))
        center.show(.info("Second"))
        #expect(center.current?.message == "First")
        center.dismiss()
        #expect(center.current?.message == "Second")
    }

    @Test func ignoresDuplicateQueuedMessages() {
        let center = PillCenter()
        center.show(.info("First"))
        center.show(.info("Again"))
        center.show(.info("Again"))
        center.dismiss()
        center.dismiss()
        #expect(center.current == nil)
    }
}
