import Foundation
import SwiftUI
import Testing
@testable import Screens

// The checks a project writes, one per row of docs/LAYOUT_CONTRACT.md, with the result each
// fixture screen must give.
@MainActor
struct LayoutContractTests {
    @Test func aBarWiderThanTheMinimumIsReported() {
        let problems = LayoutContract.check("LibraryView") { LibraryView() }
        #expect(problems == ["LAYOUT_CONTRACT.md:9 LibraryView: at 640x400 it needs 772 pt of width. Content is clipped or pushed out of the window: let it shrink, wrap or collapse (ViewThatFits, a menu) below this width."])
    }

    // The reason View and Window are measured apart: a minimum frame hides the overflow.
    @Test func theWindowFrameHidesTheOverflowButDeclaresMin() {
        #expect(LayoutContract.check("LibraryWindow") { LibraryWindow() } == [])
    }

    @Test func aBarThatCollapsesHolds() {
        #expect(LayoutContract.check("CompactLibraryView") { CompactLibraryView() } == [])
    }

    @Test func aWindowThatCannotReachMinIsReported() throws {
        let url = try contract("| x | LibraryView | f | LibraryWindow | 600x400 | - | - | - |")
        #expect(LayoutContract.check("LibraryWindow", contract: url) { LibraryWindow() } == ["\(url.lastPathComponent):5 LibraryWindow: the window cannot shrink to Min 600x400: its minimum is 640x400. Make the content fit at Min, or change Min in the contract."])
    }

    @Test func aWindowWithoutAMinimumIsReported() {
        let problems = LayoutContract.check("UnboundedWindow") { UnboundedWindow() }
        #expect(problems == ["LAYOUT_CONTRACT.md:11 UnboundedWindow: the window declares a minimum of 0x0, below Min 480x300, so it can shrink to a size the screen was not designed for. Declare it on the window's root: .frame(minWidth: 480, minHeight: 300)."])
    }

    @Test func aPaneTallerThanItsMinimumIsReported() {
        let problems = LayoutContract.check("InspectorPane") { InspectorPane() }
        #expect(problems == ["LAYOUT_CONTRACT.md:12 InspectorPane: at 260x300 it needs 400 pt of height. Content is clipped: let it scroll or collapse below this height."])
    }

    @Test func aWindowWithAMaximumHolds() {
        #expect(LayoutContract.check("BoundedWindow") { BoundedWindow() } == [])
    }

    @Test func aWindowThatGrowsPastMaxIsReported() throws {
        let url = try contract("| x | UnboundedWindow | f | UnboundedWindow | 0x0 | - | 1200x900 | - |")
        let problems = LayoutContract.check("UnboundedWindow", contract: url) { UnboundedWindow() }
        #expect(problems.count == 1)
        #expect(problems.first?.contains("grows past Max 1200x900") == true)
    }

    @Test func aMissingRowIsReported() {
        let problems = LayoutContract.check("SettingsWindow") { UnboundedWindow() }
        #expect(problems == ["LAYOUT_CONTRACT.md has no row with SettingsWindow as View or Window: add one, or fix the name passed to LayoutContract.check."])
    }

    @Test func layoutPathInTheConfigIsRead() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".claude"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("design/Tests"), withIntermediateDirectories: true)
        try #"{"layout":{"path":"design/Layout.md"}}"#.write(to: root.appendingPathComponent(".claude/swift-harness.json"), atomically: true, encoding: .utf8)
        #expect(LayoutContract.locate(from: root.appendingPathComponent("design/Tests")) == root.appendingPathComponent("design/Layout.md"))
    }

    @Test func sizes() {
        #expect(LayoutContract.size("720x480") == .some(LayoutContract.Size(width: 720, height: 480)))
        #expect(LayoutContract.size("720 × 480") == .some(LayoutContract.Size(width: 720, height: 480)))
        #expect(LayoutContract.size("320pt") == .some(LayoutContract.Size(width: 320)))
        #expect(LayoutContract.size("-") == .some(nil))
        #expect(LayoutContract.size("wide") == nil)
    }

    private func contract(_ row: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).md")
        let text = "## Screens\n\n| Screen | View | File | Window | Min | Default | Max | Compact below |\n|---|---|---|---|---|---|---|---|\n\(row)\n"
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
