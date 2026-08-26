import XCTest

@testable import SwiftCoverageCore

final class AnalysisReportScopingTests: XCTestCase {
    private func branch(startLine: Int, endLine: Int, label: String = "if") -> LogicBranch {
        LogicBranch(
            kind: .ifThen,
            label: label,
            span: SourceSpan(startLine: startLine, startColumn: 1, endLine: endLine, endColumn: 1)
        )
    }

    private func unit(file: String, branches: [LogicBranch]) -> LogicUnit {
        LogicUnit(
            name: "f",
            signature: "f()",
            enclosingTypeName: nil,
            filePath: file,
            location: SourcePosition(line: 1, column: 1),
            branches: branches
        )
    }

    func testUnitsWithNoOverlappingChangeAreDroppedEntirely() {
        let report = AnalysisReport(
            packagePath: ".",
            units: [
                unit(file: "Touched.swift", branches: [branch(startLine: 10, endLine: 12)]),
                unit(file: "Untouched.swift", branches: [branch(startLine: 10, endLine: 12)]),
            ],
            filesWithoutLogic: []
        )

        let scoped = report.scopedToChangedLines(["Touched.swift": [11]], diffBase: "main")

        XCTAssertEqual(scoped.units.map(\.filePath), ["Touched.swift"])
        XCTAssertEqual(scoped.diffBase, "main")
    }

    func testFilesNotMentionedInTheDiffAreDroppedEvenIfPreviouslyUncovered() {
        let report = AnalysisReport(
            packagePath: ".",
            units: [unit(file: "OnlyInBaseline.swift", branches: [branch(startLine: 1, endLine: 2)])],
            filesWithoutLogic: []
        )

        // The changed-lines map has no entry at all for this file — as if
        // the diff never touched it.
        let scoped = report.scopedToChangedLines([:], diffBase: "main")

        XCTAssertTrue(scoped.units.isEmpty)
        XCTAssertTrue(scoped.passes, "a report scoped to an empty diff has nothing to require")
    }

    func testOnlyBranchesOverlappingAChangedLineSurviveWithinATouchedFile() {
        let report = AnalysisReport(
            packagePath: ".",
            units: [
                unit(
                    file: "Mixed.swift",
                    branches: [
                        branch(startLine: 5, endLine: 7, label: "changed"),
                        branch(startLine: 50, endLine: 52, label: "untouched"),
                    ]
                )
            ],
            filesWithoutLogic: []
        )

        // Line 6 falls inside the first branch's span (5...7) but not the
        // second's (50...52).
        let scoped = report.scopedToChangedLines(["Mixed.swift": [6]], diffBase: "main")

        XCTAssertEqual(scoped.units.count, 1)
        XCTAssertEqual(scoped.units[0].branches.map(\.label), ["changed"])
    }

    func testBranchSpanningMultipleLinesCountsAsTouchedIfAnyLineChanged() {
        let report = AnalysisReport(
            packagePath: ".",
            units: [unit(file: "Multiline.swift", branches: [branch(startLine: 5, endLine: 20)])],
            filesWithoutLogic: []
        )

        // Only the last line of the branch's span was actually changed.
        let scoped = report.scopedToChangedLines(["Multiline.swift": [20]], diffBase: "main")

        XCTAssertEqual(scoped.requiredBranchCount, 1)
    }
}
