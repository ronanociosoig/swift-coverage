import XCTest

@testable import TortureTest

final class MacrosTests: XCTestCase {
    // Both outcomes of describe()'s `if`, unrelated to the macro invocation
    // it contains — see the doc comment on MacroUsage.
    func testDescribePositive() {
        // #stringify(n) captures the source text "n", not the runtime value.
        XCTAssertEqual(MacroUsage().describe(5), "n = 5, positive")
    }

    func testDescribeNonPositive() {
        XCTAssertEqual(MacroUsage().describe(-1), "non-positive")
    }
}
