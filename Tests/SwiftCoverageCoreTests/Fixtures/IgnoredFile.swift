// swift-coverage:ignore-file
import Foundation

struct AlsoEntirelyIgnored {
    func hasLogic(_ n: Int) -> String {
        if n < 0 {
            return "negative"
        }
        return "non-negative"
    }
}
