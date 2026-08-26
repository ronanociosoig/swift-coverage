/// Turns an uncovered branch into a concrete, actionable next step — for an
/// agent driving a write-test/rerun loop, "case .vip is uncovered" is a
/// fact; "add a test to Discount.tierName that passes .vip" is something to
/// act on directly. Templated from `BranchKind` and the branch's own label
/// (which, per `BranchCollector`, already carries the actual condition/
/// pattern text for every kind that has one), not free-form generation —
/// every suggestion is mechanically derived, so it's exactly as trustworthy
/// as the branch detection itself, no more and no less.
public enum SuggestionGenerator {
    public static func suggest(for branch: LogicBranch, in unit: LogicUnit) -> String {
        let qualifiedName = unit.enclosingTypeName.map { "\($0).\(unit.name)" } ?? unit.name

        switch branch.kind {
        case .ifThen:
            return "Add a test calling \(qualifiedName) where \(condition(from: branch.label, prefix: "if ")) is true."
        case .ifElse:
            return "Add a test calling \(qualifiedName) where the preceding `if` condition is false."
        case .guardElse:
            let condition = condition(from: branch.label, prefix: "guard ", suffix: " else")
            return "Add a test calling \(qualifiedName) where \(condition) fails, taking the guard's `else` path."
        case .switchCase:
            return "Add a test calling \(qualifiedName) with a value matching `\(branch.label)`."
        case .forLoop:
            return "Add a test calling \(qualifiedName) with a non-empty `\(branch.label)` so the loop body runs at least once."
        case .whileLoop:
            return
                "Add a test calling \(qualifiedName) where \(condition(from: branch.label, prefix: "while ")) is true on entry."
        case .repeatLoop:
            return "Add a test that reaches this `repeat`-`while` loop in \(qualifiedName) (its body always runs at least once)."
        case .catchClause:
            let what = branch.label == "catch" ? "an error" : condition(from: branch.label, prefix: "catch ")
            return "Add a test calling \(qualifiedName) where the code under test throws \(what)."
        case .ternaryThen:
            return "Add a test calling \(qualifiedName) where the ternary's condition is true."
        case .ternaryElse:
            return "Add a test calling \(qualifiedName) where the ternary's condition is false."
        case .nilCoalescing:
            return "Add a test calling \(qualifiedName) where the left-hand side of `??` is nil."
        }
    }

    /// Strips a known prefix/suffix off a label to recover just the
    /// condition text, e.g. `"if a && b"` -> `"a && b"`. Falls back to the
    /// full label if it doesn't start with the expected prefix (labels are
    /// truncated with an ellipsis past 60 characters, which could in
    /// principle land mid-prefix for a pathological condition).
    private static func condition(from label: String, prefix: String, suffix: String = "") -> String {
        var text = label
        if text.hasPrefix(prefix) { text.removeFirst(prefix.count) }
        if !suffix.isEmpty, text.hasSuffix(suffix) { text.removeLast(suffix.count) }
        return "`\(text)`"
    }
}
