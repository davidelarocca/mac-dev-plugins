import XCTest
@testable import Kit

final class KitTests: XCTestCase {
    func testCompiledForThePlatformItRunsOn() {
        #if os(iOS)
        XCTAssertEqual(Platform.name, "iOS")
        #else
        XCTAssertEqual(Platform.name, "macOS")
        #endif
    }

    #if os(iOS)
    /// Negative control: with TEST_RUNNER_SH_FAIL_ON_IOS=1, xcodebuild passes SH_FAIL_ON_IOS to the
    /// test process, and this fails on the simulator only. It proves the iOS tests really ran.
    func testNegativeControlFailsOnIOSWhenAsked() {
        let asked = ProcessInfo.processInfo.environment["SH_FAIL_ON_IOS"]
        XCTAssertNil(asked, "negative control: failing on iOS on purpose")
    }
    #endif
}
