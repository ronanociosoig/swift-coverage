import XCTest

@testable import SwiftCoverageCore

final class AnalysisReportTests: XCTestCase {
    private func branch(covered: Bool?, suppressed: Bool = false) -> LogicBranch {
        LogicBranch(
            kind: .ifThen,
            label: "if",
            span: SourceSpan(startLine: 1, startColumn: 1, endLine: 2, endColumn: 1),
            isSuppressed: suppressed,
            isCovered: covered
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

    func testUnresolvedCoverageCountsAsUncovered() {
        // isCovered == nil means "no coverage data for this branch's file at
        // all" — that must not silently pass, or a whole untested file could
        // slip through unnoticed.
        let report = AnalysisReport(
            packagePath: ".",
            units: [unit([branch(covered: nil)])],
            filesWithoutLogic: []
        )
        XCTAssertFalse(report.passes)
        XCTAssertEqual(report.uncoveredRequiredBranchCount, 1)
        XCTAssertEqual(report.units[0].unresolvedBranches.count, 1)
    }
}
