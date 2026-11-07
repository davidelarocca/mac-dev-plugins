import XCTest

/// FocusOrder from the setup templates on the fixture's focus screen (#52). The order and the
/// missing-control cases need Keyboard navigation on: CI turns it on; with it off they skip.
final class FocusOrderTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-focus"] + arguments
        app.launch()
        return app
    }

    @MainActor
    func testFocusOrderFollowsTheScreen() throws {
        try FocusOrder.check(launch(), ["play", "search", "shuffle", "queue", "details"])
    }

    @MainActor
    func testAWrongOrderFails() throws {
        try XCTSkipUnless(FocusOrder.keyboardNavigationEnabled, "Keyboard navigation is off")
        let app = launch()
        XCTExpectFailure("the expected order swaps search and play") {
            try? FocusOrder.check(app, ["search", "play", "shuffle", "queue", "details"])
        }
    }

    @MainActor
    func testAControlOutOfTheTabLoopFails() throws {
        try XCTSkipUnless(FocusOrder.keyboardNavigationEnabled, "Keyboard navigation is off")
        let app = launch(["-skipShuffle"])
        XCTExpectFailure("the shuffle toggle is not focusable") {
            try? FocusOrder.check(app, ["play", "search", "shuffle", "queue", "details"])
        }
    }

    /// Keyboard actions of the app: a shortcut opens the sheet, Escape closes it. These do not
    /// depend on Keyboard navigation.
    @MainActor
    func testShortcutOpensAndEscapeClosesTheSheet() {
        let app = launch()
        let sheet = app.descendants(matching: .any)["detailsSheet"]
        app.typeKey("i", modifierFlags: .command)
        XCTAssertTrue(sheet.waitForExistence(timeout: 3), "Command-I did not open the details sheet")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 3), "Escape did not close the details sheet")
    }
}
