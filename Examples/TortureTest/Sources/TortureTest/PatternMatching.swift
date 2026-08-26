public enum Shape {
    case circle(radius: Double)
    case square(side: Double)
    case rectangle(width: Double, height: Double)
}

/// `if case`, `guard case let`, and `switch` (with `where` clauses,
/// comma-separated patterns, and a `default`).
public struct PatternMatching {
    public init() {}

    /// `if case` without a full switch. swift-coverage treats this exactly
    /// like a plain `if`/`else`: one obligation for the pattern-matched
    /// body, one for the fallback — matching is not pattern-aware beyond
    /// that. Fully exercised.
    public func isCircle(_ shape: Shape) -> Bool {
        if case .circle = shape {
            return true
        }
        return false
    }

    /// `guard case let` binds an associated value. Deliberately left with
    /// only the "pattern matches" case tested (see
    /// `PatternMatchingTests.testGuardCaseLetMatches`) — the `else` body is
    /// left uncovered on purpose.
    public func circleRadius(_ shape: Shape) -> Double? {
        guard case .circle(let radius) = shape else {
            return nil
        }
        return radius
    }

    /// `switch` with a `where` clause on one case and a `default`. Every
    /// case here is a distinct branch obligation, matched by its own
    /// coverage region — `default` is no different from a named case.
    /// Fully exercised across all three paths.
    public func classify(_ shape: Shape) -> String {
        switch shape {
        case .circle(let radius) where radius > 10:
            return "large circle"
        case .circle:
            return "small circle"
        default:
            return "not a circle"
        }
    }

    /// Comma-separated patterns in one `case` share a single body, and so a
    /// single obligation — reaching it via *either* pattern satisfies it.
    /// Deliberately exercised via only one of the two patterns (see
    /// `PatternMatchingTests.testCommaSeparatedPatterns`), which should
    /// still mark the shared body covered: this isn't a gap to prove, it's
    /// confirming comma-patterns don't require each alternative separately.
    public func isNonRectangular(_ shape: Shape) -> Bool {
        switch shape {
        case .square, .circle:
            return true
        default:
            return false
        }
    }
}
