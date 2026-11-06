// Accessibility audit for UI tests, from the swift-harness setup templates (#36).
// Copy into a UI test target (XCUITest). It runs Apple's audit (macOS 14, iOS 17 or later) on
// the screen a launched app shows: missing descriptions, contrast, hit areas, clipped text,
// traits. Every issue fails the test, except the ones listed as exceptions, each with a reason.
//
//     func testLibraryScreen() throws {
//         let app = XCUIApplication()
//         app.launch()
//         try AccessibilityAudit.check(app, exceptions: [
//             .init(element: "waveform", type: .contrast, reason: "decorative, the value is read by the label next to it"),
//         ])
//     }
//
// UI tests run in `scripts/verify.sh full`, not in `fast`.
//
// On macOS the audit also reports parts of the window the system draws, which the app cannot
// fix: the root group of a SwiftUI window (no description) and the title in the title bar
// (contrast, when the window is not key). `check` skips exactly these two by default and prints
// each one it skips; pass `skipWindowChrome: false` to see them fail.

import XCTest

enum AccessibilityAudit {
    /// An issue accepted on purpose. `element` is the accessibility identifier or label.
    struct Exception {
        let element: String
        let type: XCUIAccessibilityAuditType
        let reason: String
    }

    /// Audits the current screen of `app` and fails for every issue that is not an exception.
    /// An exception without a reason fails too: silencing an issue needs a why.
    @MainActor
    static func check(
        _ app: XCUIApplication,
        types: XCUIAccessibilityAuditType = .all,
        exceptions: [Exception] = [],
        skipWindowChrome: Bool = true,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        for exception in exceptions where exception.reason.trimmingCharacters(in: .whitespaces).isEmpty {
            XCTFail("Accessibility exception for '\(exception.element)' has no reason.", file: file, line: line)
        }
        let windows = app.windows.allElementsBoundByIndex.map(\.frame)
        try app.performAccessibilityAudit(for: types) { issue in
            if skipWindowChrome, isWindowChrome(issue, windows: windows) {
                print("AccessibilityAudit: skipped window chrome: \(issue.compactDescription), \(issue.element?.frame ?? .zero)")
                return true
            }
            return exceptions.contains { exception in
                exception.type.contains(issue.auditType) && matches(issue.element, exception.element)
            }
        }
    }

    /// The issues the audit finds, without failing: for tests that assert on them.
    @MainActor
    static func issues(_ app: XCUIApplication, types: XCUIAccessibilityAuditType = .all) throws -> [XCUIAccessibilityAuditIssue] {
        var found: [XCUIAccessibilityAuditIssue] = []
        try app.performAccessibilityAudit(for: types) { issue in
            found.append(issue)
            return true
        }
        return found
    }

    /// The two system-drawn parts of a macOS window: a group with no identifier and no label that
    /// fills a window, and a static text inside the top 52 pt of a window (the title bar).
    @MainActor
    static func isWindowChrome(_ issue: XCUIAccessibilityAuditIssue, windows: [CGRect]) -> Bool {
        #if os(macOS)
        guard let element = issue.element else { return false }
        let frame = element.frame
        for window in windows where window.contains(frame) {
            if issue.auditType == .sufficientElementDescription, element.elementType == .group,
               element.identifier.isEmpty, element.label.isEmpty, frame == window {
                return true
            }
            if issue.auditType == .contrast, element.elementType == .staticText, frame.maxY <= window.minY + 52 {
                return true
            }
        }
        #endif
        return false
    }

    @MainActor
    private static func matches(_ element: XCUIElement?, _ name: String) -> Bool {
        guard let element else { return false }
        return element.identifier == name || element.label == name
    }
}
