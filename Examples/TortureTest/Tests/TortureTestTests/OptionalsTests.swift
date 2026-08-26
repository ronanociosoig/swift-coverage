import XCTest

@testable import TortureTest

final class OptionalsTests: XCTestCase {
    // Deliberately only nil — see the doc comment on nameOrDefault. The
    // non-nil path has no obligation to begin with.
    func testNameOrDefault() {
        XCTAssertEqual(Optionals().nameOrDefault(nil), "anonymous")
    }

    // Covers the outer `??`'s fallback (a is nil) but not the inner one's
    // (b is non-nil, so "neither" never runs) — see the doc comment on
    // firstNonNil.
    func testFirstNonNilOuterFallbackOnly() {
        XCTAssertEqual(Optionals().firstNonNil(nil, "value"), "value")
    }

    // Deliberately only the `then` side — see the doc comment on sizeLabel.
    func testSizeLabelLargeOnly() {
        XCTAssertEqual(Optionals().sizeLabel(true), "large")
    }

    func testStreetName() {
        let withAddress = Person(address: Address(street: "Main St"))
        XCTAssertEqual(Optionals().streetName(withAddress), "Main St")

        let withoutAddress = Person(address: nil)
        XCTAssertEqual(Optionals().streetName(withoutAddress), "unknown")
    }
}
