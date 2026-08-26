import XCTest

@testable import SwiftCoverageCore

final class AnalysisReportTests: XCTestCase {
    /// `covered: true`/`false` builds a high-confidence direct-execution
    /// verdict (as if an exact-span region were matched); `nil` leaves
    /// `evidence` unset entirely, i.e. genuinely unresolved.
    private func branch(covered: Bool?, suppressed: Bool = false) -> LogicBranch {
        let evidence: CoverageEvidence? =
            covered.map { isCovered in
                CoverageEvidence(
                    kind: .directExecution,
                    status: isCovered ? .covered : .uncovered,
                    confidence: .high,
                    executionCount: isCovered ? 1 : 0,
                    detail: "test fixture"
                )
            }
        return LogicBranch(
            kind: .ifThen,
            label: "if",
            span: SourceSpan(startLine: 1, startColumn: 1, endLine: 2, endColumn: 1),
            isSuppressed: suppressed,
            evidence: evidence
        )
    }

    /// A branch resolved to a real `.unknown` verdict (as opposed to never
    /// having been resolved at all) — see `testFileNotInstrumentedCountsAsUncovered`.
    private func unresolvableBranch(suppressed: Bool = false) -> LogicBranch {
        LogicBranch(
            kind: .ifThen,
            label: "if",
            span: SourceSpan(startLine: 1, startColumn: 1, endLine: 2, endColumn: 1),
            isSuppressed: suppressed,
            evidence: CoverageEvidence(
                kind: .fileNotInstrumented, status: .unknown, confidence: .none, detail: "test fixture")
        )
    }

    private func unit(_ branches: [LogicBranch], suppressed: Bool = false) -> LogicUnit {
        LogicUnit(
            name: "f",
            signature: "f()",
            enclosingTypeName: nil,
            filePath: "a.swift",
            location: SourcePosition(line: 1, column: 1),
            branches: branches,
            isSuppressed: suppressed
        )
    }

    func testPassesWhenAllRequiredBranchesCovered() {
        let report = AnalysisReport(
            packagePath: ".",
            units: [unit([branch(covered: true), branch(covered: true)])],
            filesWithoutLogic: []
        )
        XCTAssertTrue(report.passes)
        XCTAssertEqual(report.uncoveredRequiredBranchCount, 0)
        XCTAssertEqual(report.lineCoveragePercent, 100)
    }

    func testFailsWhenAnyRequiredBranchUncovered() {
        let report = AnalysisReport(
            packagePath: ".",
            units: [unit([branch(covered: true), branch(covered: false)])],
            filesWithoutLogic: []
        )
        XCTAssertFalse(report.passes)
        XCTAssertEqual(report.uncoveredRequiredBranchCount, 1)
        XCTAssertEqual(report.lineCoveragePercent, 50)
    }

    func testSuppressedBranchesDoNotCountTowardFailure() {
        let report = AnalysisReport(
            packagePath: ".",
            units: [unit([branch(covered: false, suppressed: true)])],
            filesWithoutLogic: []
        )
        XCTAssertTrue(report.passes)
        XCTAssertNil(report.lineCoveragePercent)
    }

    func testSuppressedUnitExcludesAllItsBranches() {
        let report = AnalysisReport(
            packagePath: ".",
            units: [unit([branch(covered: false)], suppressed: true)],
            filesWithoutLogic: []
        )
        XCTAssertTrue(report.passes)
    }

    func testGenuinelyUnresolvedCoverageCountsAsUncovered() {
        // evidence == nil (resolveCoverage never ran, or a unit came from
        // collectLogicUnits() alone) must not silently pass.
        let report = AnalysisReport(
            packagePath: ".",
            units: [unit([branch(covered: nil)])],
            filesWithoutLogic: []
        )
        XCTAssertFalse(report.passes)
        XCTAssertEqual(report.uncoveredRequiredBranchCount, 1)
        XCTAssertEqual(report.units[0].unresolvedBranches.count, 1)
    }

    func testFileNotInstrumentedCountsAsUncoveredAndUnresolved() {
        // evidence.status == .unknown (resolved, but no verdict reachable)
        // must also not silently pass, and must still be distinguishable
        // from a confirmed miss via unresolvedBranches.
        let report = AnalysisReport(
            packagePath: ".",
            units: [unit([unresolvableBranch()])],
            filesWithoutLogic: []
        )
        XCTAssertFalse(report.passes)
        XCTAssertEqual(report.uncoveredRequiredBranchCount, 1)
        XCTAssertEqual(report.units[0].unresolvedBranches.count, 1)
        XCTAssertEqual(report.units[0].branches[0].evidence?.kind, .fileNotInstrumented)
    }
}
