import Foundation

struct Suppressed {
    // swift-coverage:ignore
    func entirelyIgnored(_ n: Int) -> String {
        if n < 0 {
            return "negative"
        }
        return "non-negative"
    }

    func partiallyIgnored(_ n: Int) -> String {
        // swift-coverage:ignore-branch
        if n < 0 {
            return "negative"
        }
        return "non-negative"
    }
}
