import XCTest

@testable import TortureTest

final class ErrorHandlingTests: XCTestCase {
    // Only the success path and the `.validation` catch clause — see the
    // doc comment on run(). `.network` and the catch-all are expected to
    // show up as uncovered.
    func testRunSuccess() {
        XCTAssertEqual(ErrorHandling().run { 42 }, "ok: 42")
    }

    func testRunValidationFailure() {
        XCTAssertEqual(
            ErrorHandling().run { throw TortureError.validation("bad input") },
            "validation failed: bad input"
        )
    }

    // `defer`'s mutation runs after the return value is already computed,
    // so it never shows up in the string itself — that's expected, not a bug.
    func testWithCleanup() {
        XCTAssertEqual(ErrorHandling().withCleanup(true), "failed")
        XCTAssertEqual(ErrorHandling().withCleanup(false), "succeeded")
    }
}
