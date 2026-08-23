import XCTest

@testable import DemoPackage

final class DiscountTests: XCTestCase {
    func testStandardTier() {
        XCTAssertEqual(Discount().percentOff(for: .standard, isFirstOrder: false), 0)
    }

    func testGoldTierFirstOrder() {
        XCTAssertEqual(Discount().percentOff(for: .gold, isFirstOrder: true), 15)
    }

    func testVipTier() {
        XCTAssertEqual(Discount().percentOff(for: .vip, isFirstOrder: false), 20)
    }

    // tierName() is only exercised for .standard and .gold here — .vip is
    // left deliberately untested so the integration test can assert
    // swift-coverage catches it.
    func testTierNameStandard() {
        XCTAssertEqual(Discount().tierName(for: .standard), "Standard")
    }

    func testTierNameGold() {
        XCTAssertEqual(Discount().tierName(for: .gold), "Gold")
    }

    func testLegacyNormalize() {
        XCTAssertEqual(Legacy().normalize(5), 5)
    }
}
