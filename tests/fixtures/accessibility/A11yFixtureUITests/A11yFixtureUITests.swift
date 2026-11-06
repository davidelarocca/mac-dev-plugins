import XCTest

/// The template helper on the fixture: the audit finds the button without a description, and
/// the fixed screen passes the full audit.
final class A11yFixtureUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTheAuditFindsAButtonWithoutDescription() throws {
        let app = XCUIApplication()
        app.launch()
        let issues = try AccessibilityAudit.issues(app)
        let windows = app.windows.allElementsBoundByIndex.map(\.frame)
        let described = issues.filter {
            $0.auditType == .sufficientElementDescription && $0.element?.identifier == "favorite"
        }
        XCTAssertFalse(described.isEmpty, "expected a sufficientElementDescription issue, got: \(issues.map { "\($0.auditType.rawValue) \($0.compactDescription)" })")
        XCTAssertTrue(issues.contains { AccessibilityAudit.isWindowChrome($0, windows: windows) }, "the window root group is chrome on macOS")
        print("swift-harness a11y negative control:", issues.map { "\($0.auditType.rawValue): \($0.compactDescription) on \($0.element.map { "\($0.elementType.rawValue) id=\($0.identifier) label=\($0.label) frame=\($0.frame)" } ?? "none")" })
    }

    @MainActor
    func testTheFixedScreenPassesTheAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-labeled"]
        app.launch()
        try AccessibilityAudit.check(app)
    }

    @MainActor
    func testAnExceptionSilencesOnlyItsIssue() throws {
        let app = XCUIApplication()
        app.launch()
        try AccessibilityAudit.check(app, types: .sufficientElementDescription, exceptions: [
            .init(element: "favorite", type: .sufficientElementDescription, reason: "fixture: the issue the negative control expects"),
        ])
    }

    @MainActor
    func testAnExceptionDoesNotSilenceOtherIssues() throws {
        let app = XCUIApplication()
        app.launch()
        // With the window chrome not skipped, the root group is still reported: the exception
        // for "favorite" covers that element only.
        XCTExpectFailure("the window's root group has no description") {
            try? AccessibilityAudit.check(app, types: .sufficientElementDescription, exceptions: [
                .init(element: "favorite", type: .sufficientElementDescription, reason: "fixture"),
            ], skipWindowChrome: false)
        }
    }
}
