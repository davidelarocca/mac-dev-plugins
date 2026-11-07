import XCTest
#if os(macOS)
import ApplicationServices
import AppKit
#endif

/// Spike #69 (temporary): what XCUIElement frames show, and how a test sets the window size.
final class LayoutSpikeTests: XCTestCase {
    func dump(_ app: XCUIApplication, _ tag: String) throws {
        let snap = try app.snapshot()
        func walk(_ s: XCUIElementSnapshot, _ depth: Int) {
            // Skip the menu bar: hundreds of zero-size items.
            if s.elementType == .menuBar { return }
            print("SPIKE \(tag) " + String(repeating: "  ", count: depth) + "\(s.elementType.rawValue) id=\(s.identifier) label=\(s.label) value=\(String(describing: s.value)) frame=\(s.frame)")
            for c in s.children { walk(c, depth + 1) }
        }
        walk(snap, 0)
    }

    @MainActor
    func testDumpDefault() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-layout"]
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        try dump(app, "default")
        print("SPIKE hittable below=\(app.staticTexts["below"].isHittable) row0=\(app.buttons["row0"].isHittable) line19=\(app.staticTexts["line19"].isHittable)")
    }

    #if os(iOS)
    @MainActor
    func testDumpLargeText() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-layout", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        try dump(app, "xxxl")
    }

    @MainActor
    func testDumpLandscape() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-layout"]
        app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        sleep(1)
        try dump(app, "landscape")
    }
    #endif

    #if os(macOS)
    @MainActor
    func testResizeWays() throws {
        print("SPIKE trusted=\(AXIsProcessTrusted())")
        let app = XCUIApplication()
        app.launchArguments = ["-layout"]
        app.launch()
        let w = app.windows.firstMatch
        XCTAssertTrue(w.waitForExistence(timeout: 10))
        print("SPIKE resize before \(w.frame)")

        // 1. Drag the bottom-right corner up-left.
        let c = w.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1)).withOffset(CGVector(dx: -2, dy: -2))
        c.press(forDuration: 0.5, thenDragTo: c.withOffset(CGVector(dx: -600, dy: -400)))
        print("SPIKE resize drag \(w.frame)")

        // 2. The AX size attribute, set from the test process.
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: "dev.swiftharness.A11yFixture").first {
            let ax = AXUIElementCreateApplication(running.processIdentifier)
            var windows: CFTypeRef?
            let e = AXUIElementCopyAttributeValue(ax, kAXWindowsAttribute as CFString, &windows)
            print("SPIKE ax windows err=\(e.rawValue) count=\((windows as? [AXUIElement])?.count ?? -1)")
            if let win = (windows as? [AXUIElement])?.first {
                var size = CGSize(width: 1, height: 1)
                let v = AXValueCreate(.cgSize, &size)!
                let r = AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, v)
                print("SPIKE ax set err=\(r.rawValue)")
                sleep(1)
                print("SPIKE resize ax \(w.frame)")
            }
        } else {
            print("SPIKE no running app")
        }
        try dump(app, "small")

        // 3. The autosaved frame default, from a launch argument.
        let id = w.identifier
        app.terminate()
        app.launchArguments = ["-layout", "-NSWindow Frame \(id)", "100 100 310 330 0 0 1920 1050"]
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        print("SPIKE resize default-arg \(app.windows.firstMatch.frame)")
    }
    #endif
}
