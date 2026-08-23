/// A worked example for the swift-coverage README and integration tests.
///
/// `percentOff` is fully exercised by `DemoPackageTests`. `tierName`'s
/// `.vip` case is deliberately never tested, so `swift-coverage` should
/// report it as an uncovered logic path — this is exactly the kind of gap a
/// blanket line/statement percentage can hide behind everything else here
/// being well tested.
public struct Discount {
    public enum Tier {
        case standard
        case gold
        case vip
    }

    public init() {}

    public func percentOff(for tier: Tier, isFirstOrder: Bool) -> Int {
        var percent: Int
        switch tier {
        case .standard:
            percent = 0
        case .gold:
            percent = 10
        case .vip:
            percent = 20
        }
        if isFirstOrder {
            percent += 5
        }
        return percent
    }

    public func tierName(for tier: Tier) -> String {
        switch tier {
        case .standard:
            return "Standard"
        case .gold:
            return "Gold"
        case .vip:
            return "VIP"
        }
    }
}
