import SwiftUI
import Testing
@testable import DesignSystem

// Visual regression for a shared component, with the Snapshot helper from the swift-harness
// setup templates (tests/Snapshot.swift, next to LayoutContract.swift and Screenshot.swift in
// this test target). No package dependency. Each call checks light and dark against the
// baselines in snapshots/; a missing or different image fails the test and waits for the
// user's approval (/swift-harness:approve-snapshots). The test never writes a baseline.
//
// One suite per component is the gallery: every state, long text, a long language and a
// right-to-left one.

@MainActor
@Suite("PillView snapshots")
struct PillViewSnapshotTests {
    @Test(arguments: [Pill.info("Info"), .success("Added to library"), .warning("Low disk space"), .error("Import failed")])
    func kinds(pill: Pill) {
        #expect(Snapshot.verify("PillView", sizes: ["320"], state: "\(pill.kind)", source: "Sources/DesignSystem/Components/Pill/PillView.swift") {
            PillView(pill: pill)
        } == [])
    }

    @Test func longText() {
        let pill = Pill.success(String(repeating: "Very long album title ", count: 6))
        #expect(Snapshot.verify("PillView", sizes: ["320"], state: "long-text") { PillView(pill: pill) } == [])
    }

    @Test(arguments: ["de", "ar"])
    func localized(locale: String) {
        #expect(Snapshot.verify("PillView", sizes: ["320"], state: "success", locale: locale) {
            PillView(pill: .success("Added to library"))
        } == [])
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
