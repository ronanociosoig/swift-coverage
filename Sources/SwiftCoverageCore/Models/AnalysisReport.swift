/// The result of analyzing a package: every logic unit found, each with its
/// branches resolved to covered/uncovered against a coverage profile (or
/// left unresolved if `--skip-tests` was used and no profile was available).
public struct AnalysisReport: Sendable {
    public var packagePath: String
    public var units: [LogicUnit]
    /// Files that were parsed but produced no `LogicUnit`s (pure data types,
    /// re-exports, etc.) — surfaced for transparency, not as a problem.
    public var filesWithoutLogic: [String]

    public init(packagePath: String, units: [LogicUnit], filesWithoutLogic: [String]) {
        self.packagePath = packagePath
        self.units = units
        self.filesWithoutLogic = filesWithoutLogic
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
}
