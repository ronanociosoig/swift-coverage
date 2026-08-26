import XCTest

@testable import TortureTest

final class LoopsTests: XCTestCase {
    // Deliberately never called with n == 0 — see the doc comment on
    // countDown(). The "ran zero times" outcome is genuinely never
    // exercised, and (per documented behavior) never flagged either.
    func testCountDown() {
        XCTAssertEqual(Loops().countDown(3), 0)
    }

    func testRepeatUntilZero() {
        XCTAssertEqual(Loops().repeatUntilZero(3), 0)
    }

    func testSumEvenNumbers() {
        XCTAssertEqual(Loops().sumEvenNumbers([1, 2, 3, 4, 5]), 6)
    }
}
