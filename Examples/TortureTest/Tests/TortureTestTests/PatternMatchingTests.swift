import XCTest

@testable import TortureTest

final class PatternMatchingTests: XCTestCase {
    func testIsCircle() {
        XCTAssertTrue(PatternMatching().isCircle(.circle(radius: 1)))
        XCTAssertFalse(PatternMatching().isCircle(.square(side: 1)))
    }

    // Deliberately only the pattern-matches case — see the doc comment on
    // circleRadius. The guard's `else` body is expected to show up as
    // uncovered.
    func testGuardCaseLetMatches() {
        XCTAssertEqual(PatternMatching().circleRadius(.circle(radius: 4)), 4)
    }

    func testClassify() {
        XCTAssertEqual(PatternMatching().classify(.circle(radius: 20)), "large circle")
        XCTAssertEqual(PatternMatching().classify(.circle(radius: 5)), "small circle")
        XCTAssertEqual(PatternMatching().classify(.square(side: 1)), "not a circle")
    }

    // Only the `.square` half of the comma-separated pattern is exercised —
    // see the doc comment on isNonRectangular.
    func testCommaSeparatedPatterns() {
        XCTAssertTrue(PatternMatching().isNonRectangular(.square(side: 1)))
        XCTAssertFalse(PatternMatching().isNonRectangular(.rectangle(width: 2, height: 3)))
    }
}
