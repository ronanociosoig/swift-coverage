/// Whether a branch ran, as far as swift-coverage could determine.
/// `unknown` is a distinct state from `uncovered` — it means no verdict
/// could be reached at all, not that one was reached and it was negative.
/// It still counts as a failure for `AnalysisReport.passes` (see
/// `LogicUnit.uncoveredRequiredBranches`): "no evidence this ran" is
/// exactly the kind of gap a percentage threshold can hide, so it isn't
/// treated as a pass by default — but callers can now see *why* a branch
/// failed instead of a single opaque `false`.
public enum CoverageStatus: String, Sendable, Codable {
    case covered
    case uncovered
    case unknown
}

/// How much to trust `CoverageEvidence.status` — derived mechanically from
/// `kind`, not a separate judgment call. See `CoverageEvidenceKind`.
public enum CoverageConfidence: String, Sendable, Codable {
    /// The matched region unambiguously *is* this branch.
    case high
    /// The status was inferred from a region that isn't exactly this
    /// branch's own span — still a real signal, but a heuristic one.
    case medium
    /// No region-based verdict was possible at all.
    case none
}

/// What swift-coverage actually found when matching a branch's source span
/// against the coverage export — making the heuristic nature of that match
/// explicit and inspectable, rather than presenting a bare `Bool` as if it
/// were ground truth. See `SEMANTICS.md` for which constructs land on which
/// kind in practice.
public enum CoverageEvidenceKind: String, Sendable, Codable {
    /// The matched coverage region's span exactly equals the branch's own
    /// span: this region *is* the branch, not a proxy standing in for it.
    /// Typical for `if`/`guard`/loop/`catch` bodies, whose span already
    /// starts and ends where the compiler's own region does.
    case directExecution = "direct_execution"
    /// A region was matched — the innermost one whose span contains the
    /// branch's start position — but its span differs from the branch's
    /// own. Typical for `switch` cases, where the compiler's region starts
    /// at the `case` label rather than the case's first statement.
    case inferredFromEnclosingRegion = "inferred_from_enclosing_region"
    /// The branch's file has coverage data (it was instrumented and
    /// compiled into a tested target), but no region's span contains the
    /// branch's start position at all.
    case noMatchingRegion = "no_matching_region"
    /// The branch's file has no coverage data in the export whatsoever —
    /// most often because it wasn't compiled into any tested target.
    case fileNotInstrumented = "file_not_instrumented"
}

/// The full verdict-plus-justification for one branch's coverage status.
public struct CoverageEvidence: Sendable {
    public var kind: CoverageEvidenceKind
    public var status: CoverageStatus
    public var confidence: CoverageConfidence
    /// The matched region's span, when `kind` is `.directExecution` or
    /// `.inferredFromEnclosingRegion`; `nil` otherwise.
    public var matchedRegionSpan: SourceSpan?
    /// The matched region's execution count, when a region was matched;
    /// `nil` otherwise.
    public var executionCount: Int?
    /// A short human-readable justification, e.g. the matched region's span
    /// and count, or why nothing matched.
    public var detail: String

    public init(
        kind: CoverageEvidenceKind,
        status: CoverageStatus,
        confidence: CoverageConfidence,
        matchedRegionSpan: SourceSpan? = nil,
        executionCount: Int? = nil,
        detail: String
    ) {
        self.kind = kind
        self.status = status
        self.confidence = confidence
        self.matchedRegionSpan = matchedRegionSpan
        self.executionCount = executionCount
        self.detail = detail
    }
}
