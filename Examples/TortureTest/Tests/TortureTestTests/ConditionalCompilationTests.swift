import XCTest

@testable import TortureTest

final class ConditionalCompilationTests: XCTestCase {
    func testPlatformName() {
        // Whichever #if clause compiled for this platform; there's no
        // branch obligation for #if itself either way.
        XCTAssertFalse(ConditionalCompilation().platformName().isEmpty)
    }

    func testDescribeCount() {
        XCTAssertEqual(ConditionalCompilation().describeCount(3), "3 items")
    }

    // Deliberately only the "modern" path — see the doc comment on
    // modernAPIDescription(). The "legacy" path can't run on this machine.
    func testModernAPIDescription() {
        XCTAssertEqual(ConditionalCompilation().modernAPIDescription(), "modern")
    }
}
