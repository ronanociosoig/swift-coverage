/// Compound boolean conditions (`&&`, `||`). swift-coverage creates exactly
/// one `if-then`/`if-else` obligation for the *whole* condition, regardless
/// of how many `&&`/`||` operands it contains — it does not create separate
/// obligations per operand outcome (e.g. "`a` false", "`a` true, `b`
/// never evaluated by short-circuit", "both true"). See `SEMANTICS.md`.
///
/// Every function here uses an explicit `else`, not a bare `if` followed by
/// an unconditional `return` — the latter produces only one obligation
/// (there's no written alternative to require), which is a different,
/// deliberately separate claim demonstrated elsewhere (see
/// `ConditionalCompilation.describeCount`). These functions exist
/// specifically to show both obligations of a compound condition.
public struct CompoundConditions {
    public init() {}

    /// Fully exercised: tests cover both "condition true" and "condition
    /// false", so both this function's obligations are covered. That
    /// coverage says nothing about which combination of `a`/`b` values were
    /// actually used to reach each outcome — see `SEMANTICS.md`.
    public func requiresBothTrue(_ a: Bool, _ b: Bool) -> String {
        if a && b {
            return "both"
        } else {
            return "not both"
        }
    }

    /// Deliberately left with only the "true" outcome tested (see
    /// `CompoundConditionsTests`) — swift-coverage should report the `else`
    /// body as an uncovered logic path.
    public func requiresEitherTrue(_ a: Bool, _ b: Bool) -> String {
        if a || b {
            return "at least one"
        } else {
            return "neither"
        }
    }

    /// Nested three-operand compound condition — still a single obligation
    /// per branch, fully exercised.
    public func nestedCompound(_ a: Bool, _ b: Bool, _ c: Bool) -> String {
        if (a && b) || (!a && c) {
            return "matched"
        } else {
            return "unmatched"
        }
    }
}
