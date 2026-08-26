import XCTest

@testable import TortureTest

final class ResultBuilderTests: XCTestCase {
    // Both sides of the if/else (buildEither) plus the bare-if
    // (buildOptional) true path — see the doc comment on greeting().
    func testGreetingFormal() {
        XCTAssertEqual(
            Greeter().greeting(name: "Ada", isFormal: true, includeTime: true, time: "3pm"),
            "Good day, Ada. It's 3pm."
        )
    }

    func testGreetingInformal() {
        XCTAssertEqual(
            Greeter().greeting(name: "Ada", isFormal: false, includeTime: false, time: "3pm"),
            "Hey Ada!"
        )
    }
}
