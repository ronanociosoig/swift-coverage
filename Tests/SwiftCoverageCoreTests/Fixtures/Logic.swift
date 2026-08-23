import Foundation

/// A grab-bag of every branch construct swift-coverage recognizes, used by
/// `BranchCollectorTests` and `LogicUnitCollectorTests` to check both branch
/// counts and (via a canned coverage export) covered/uncovered resolution.
struct Logic {
    func classify(_ n: Int) -> String {
        if n < 0 {
            return "negative"
        } else if n == 0 {
            return "zero"
        } else {
            return "positive"
        }
    }

    func guarded(_ n: Int?) -> Int {
        guard let n else {
            return -1
        }
        return n
    }

    func switcher(_ n: Int) -> String {
        switch n {
        case 0:
            return "zero"
        case 1:
            return "one"
        default:
            return "many"
        }
    }

    func looped(_ items: [Int]) -> Int {
        var total = 0
        for item in items {
            total += item
        }
        return total
    }

    func spun(_ n: Int) -> Int {
        var count = n
        while count > 0 {
            count -= 1
        }
        return count
    }

    func repeated(_ n: Int) -> Int {
        var count = n
        repeat {
            count -= 1
        } while count > 0
        return count
    }

    func caught(_ perform: () throws -> Void) -> String {
        do {
            try perform()
            return "ok"
        } catch {
            return "failed"
        }
    }

    func ternary(_ flag: Bool) -> String {
        let result = flag ? "yes" : "no"
        return result
    }

    func fallback(_ value: Int?) -> Int {
        let result = value ?? -1
        return result
    }

    enum State { case a, b }
    var state: State = .a

    /// A shorthand (getter-only) computed property, structurally identical
    /// to how every SwiftUI `body` is written. Regression coverage for a bug
    /// where wrapping a shorthand getter's statements in a freshly
    /// constructed `CodeBlockSyntax` (to satisfy an API that wanted a full
    /// code block) corrupted every position computed inside it, since the
    /// synthetic parent's own unpositioned tokens became the position base.
    var describedState: String {
        switch state {
        case .a:
            return "a"
        case .b:
            return "b"
        }
    }
}
