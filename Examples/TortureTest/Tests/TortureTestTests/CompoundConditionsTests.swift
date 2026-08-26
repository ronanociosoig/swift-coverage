import XCTest

@testable import TortureTest

final class CompoundConditionsTests: XCTestCase {
    func testRequiresBothTrue() {
        XCTAssertEqual(CompoundConditions().requiresBothTrue(true, true), "both")
        XCTAssertEqual(CompoundConditions().requiresBothTrue(true, false), "not both")
    }

    // Deliberately only the "true" outcome — see the doc comment on
    // requiresEitherTrue. The `else` body is expected to show up as
    // uncovered.
    func testRequiresEitherTrue() {
        XCTAssertEqual(CompoundConditions().requiresEitherTrue(true, false), "at least one")
    }

    func testNestedCompound() {
        XCTAssertEqual(CompoundConditions().nestedCompound(true, true, false), "matched")
        XCTAssertEqual(CompoundConditions().nestedCompound(false, true, true), "matched")
        XCTAssertEqual(CompoundConditions().nestedCompound(false, true, false), "unmatched")
    }
}
