/// The kind of decision point a `LogicBranch` represents. Each case is one
/// alternate path through a function that `swift test` either did or didn't
/// exercise.
public enum BranchKind: String, Sendable, Codable {
    case ifThen = "if"
    case ifElse = "else"
    case guardElse = "guard-else"
    case switchCase = "case"
    case forLoop = "for"
    case whileLoop = "while"
    case repeatLoop = "repeat-while"
    case catchClause = "catch"
    case ternaryThen = "ternary-then"
    case ternaryElse = "ternary-else"
    case nilCoalescing = "nil-coalescing"

    /// Whether this branch kind is worth flagging even when its body is a
    /// single trivial statement (loops and catch clauses always are, since
    /// "ran zero iterations" / "never threw" is itself a real, distinct path).
    public var isAlwaysSignificant: Bool {
        switch self {
        case .forLoop, .whileLoop, .repeatLoop, .catchClause:
            return true
        default:
            return false
        }
    }
}

/// One alternate path through a function body — the body of an `if`/`else`,
/// one `switch` case, a loop body, a `catch` clause, or a ternary/`??`
/// alternative. This is the unit `swift-coverage` requires tests to reach;
/// it is intentionally finer-grained than "percent of lines executed".
public struct LogicBranch: Sendable {
    public var kind: BranchKind
    /// Short human label, e.g. `"case .success"`, `"else"`, `"catch NetworkError"`.
    public var label: String
    public var span: SourceSpan
    /// Set when a `// swift-coverage:ignore-branch` annotation applies directly to this branch.
    public var isSuppressed: Bool
    /// Filled in once coverage data has been matched against this branch's span.
    /// `nil` until `SwiftCoverageAnalyzer` cross-references the coverage report.
    public var isCovered: Bool?

    public init(
        kind: BranchKind,
        label: String,
        span: SourceSpan,
        isSuppressed: Bool = false,
        isCovered: Bool? = nil
    ) {
        self.kind = kind
        self.label = label
        self.span = span
        self.isSuppressed = isSuppressed
        self.isCovered = isCovered
    }
}

/// A function, initializer, deinitializer, or computed-property accessor that
/// contains at least one `LogicBranch` — i.e. it has actual decision logic,
/// as opposed to a plain stored property or a straight-line pass-through.
/// Declarations with zero branches never become a `LogicUnit`, which is how
/// plain data structs are excluded without any special-casing of "data
/// types": a struct with only stored properties simply never produces one.
public struct LogicUnit: Sendable {
    public var name: String
    public var signature: String
    public var enclosingTypeName: String?
    public var filePath: String
    public var location: SourcePosition
    public var branches: [LogicBranch]
    /// Set when a `// swift-coverage:ignore` annotation applies to the whole declaration.
    public var isSuppressed: Bool

    public init(
        name: String,
        signature: String,
        enclosingTypeName: String?,
        filePath: String,
        location: SourcePosition,
        branches: [LogicBranch],
        isSuppressed: Bool = false
    ) {
        self.name = name
        self.signature = signature
        self.enclosingTypeName = enclosingTypeName
        self.filePath = filePath
        self.location = location
        self.branches = branches
        self.isSuppressed = isSuppressed
    }

    /// Cyclomatic complexity, derived directly from the branch count (one
    /// decision point per branch, plus the base path) rather than computed
    /// by a separate walk.
    public var cyclomaticComplexity: Int {
        1 + branches.count
    }

    /// Branches that actually require a covered/uncovered verdict: not
    /// suppressed, and belonging to a unit that isn't itself suppressed.
    public var requiredBranches: [LogicBranch] {
        isSuppressed ? [] : branches.filter { !$0.isSuppressed }
    }

    /// Branches that did not verifiably run: explicitly uncovered, *and*
    /// branches coverage data had nothing to say about (`isCovered == nil`,
    /// usually because their file wasn't compiled into any tested target).
    /// The latter is treated as a failure rather than silently passing —
    /// "we have no evidence this path ran" is exactly the kind of gap a
    /// percentage threshold can hide.
    public var uncoveredRequiredBranches: [LogicBranch] {
        requiredBranches.filter { $0.isCovered != true }
    }

    /// The subset of `uncoveredRequiredBranches` whose coverage verdict is
    /// unknown rather than confirmedly unreached — worth reporting
    /// differently, since the fix is "make sure this file is compiled into
    /// a tested target", not "add a test for this specific branch".
    public var unresolvedBranches: [LogicBranch] {
        requiredBranches.filter { $0.isCovered == nil }
    }
}
