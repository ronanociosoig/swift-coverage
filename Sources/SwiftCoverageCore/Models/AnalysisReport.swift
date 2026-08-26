/// The result of analyzing a package: every logic unit found, each with its
/// branches resolved to covered/uncovered against a coverage profile (or
/// left unresolved if `--skip-tests` was used and no profile was available).
public struct AnalysisReport: Sendable {
    public var packagePath: String
    public var units: [LogicUnit]
    /// Files that were parsed but produced no `LogicUnit`s (pure data types,
    /// re-exports, etc.) — surfaced for transparency, not as a problem.
    public var filesWithoutLogic: [String]
    /// Set when this report was narrowed to only new/changed logic via
    /// `scopedToChangedLines` — the git ref changes were computed against.
    /// `nil` for a full, unscoped report.
    public var diffBase: String?

    public init(
        packagePath: String,
        units: [LogicUnit],
        filesWithoutLogic: [String],
        diffBase: String? = nil
    ) {
        self.packagePath = packagePath
        self.units = units
        self.filesWithoutLogic = filesWithoutLogic
        self.diffBase = diffBase
    }

    public var requiredBranchCount: Int {
        units.reduce(0) { $0 + $1.requiredBranches.count }
    }

    public var uncoveredRequiredBranchCount: Int {
        units.reduce(0) { $0 + $1.uncoveredRequiredBranches.count }
    }

    public var unitsWithUncoveredLogic: [LogicUnit] {
        units.filter { !$0.uncoveredRequiredBranches.isEmpty }
    }

    /// `true` when every non-suppressed logic branch in the package was
    /// exercised by the test suite. This — not a percentage threshold — is
    /// what `swift-coverage check` gates on.
    public var passes: Bool {
        uncoveredRequiredBranchCount == 0
    }

    public var lineCoveragePercent: Double? {
        guard requiredBranchCount > 0 else { return nil }
        let covered = requiredBranchCount - uncoveredRequiredBranchCount
        return Double(covered) / Double(requiredBranchCount) * 100
    }

    /// Restricts this report to only the branches whose span overlaps a
    /// changed line in `changedLines` (file path -> 1-based line numbers
    /// added/modified by a diff, from `GitDiff.changedLines`). Units left
    /// with no in-scope branches are dropped entirely.
    ///
    /// This is what makes adopting swift-coverage in an existing,
    /// previously-untested codebase tractable: instead of every pre-existing
    /// gap failing the check at once, only logic actually touched by the
    /// current change is required — the rest is reported on the same as
    /// before (unaffected), it's just not part of *this* gate.
    ///
    /// A branch is in scope if *any* line of its own span was changed; a
    /// branch whose body is untouched but whose condition changed on a line
    /// outside that span (e.g. only the `if` keyword's own line) won't be
    /// picked up by this — see `SEMANTICS.md`.
    public func scopedToChangedLines(_ changedLines: [String: Set<Int>], diffBase: String) -> AnalysisReport {
        let scopedUnits = units.compactMap { unit -> LogicUnit? in
            guard let lines = changedLines[unit.filePath] else { return nil }
            var unit = unit
            unit.branches = unit.branches.filter { branch in
                (branch.span.start.line...branch.span.end.line).contains { lines.contains($0) }
            }
            return unit.branches.isEmpty ? nil : unit
        }
        return AnalysisReport(
            packagePath: packagePath,
            units: scopedUnits,
            filesWithoutLogic: filesWithoutLogic,
            diffBase: diffBase
        )
    }
}
