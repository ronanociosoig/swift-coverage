import XCTest

@testable import SwiftCoverageCore

final class CoverageIndexTests: XCTestCase {
    private let file = "/tmp/File.swift"

    private func makeIndex(regions: [[Int]]) -> CoverageIndex {
        let export = CoverageExport(
            data: [
                CoverageExportDatum(functions: [
                    CoverageFunctionRecord(name: "f", regions: regions, filenames: [file])
                ])
            ]
        )
        return CoverageIndex(export: export)
    }

    private func span(_ startLine: Int, _ startCol: Int, _ endLine: Int, _ endCol: Int) -> SourceSpan {
        SourceSpan(startLine: startLine, startColumn: startCol, endLine: endLine, endColumn: endCol)
    }

    // MARK: - direct_execution: the region's span exactly equals the branch's own

    func testExactSpanMatchIsDirectExecutionCovered() {
        let index = makeIndex(regions: [[1, 1, 5, 1, 1, 0, 0, 0]])
        let evidence = index.evaluate(span(1, 1, 5, 1), in: file)
        XCTAssertEqual(evidence.kind, .directExecution)
        XCTAssertEqual(evidence.status, .covered)
        XCTAssertEqual(evidence.confidence, .high)
        XCTAssertEqual(evidence.executionCount, 1)
    }

    func testExactSpanMatchIsDirectExecutionUncovered() {
        let index = makeIndex(regions: [[1, 1, 5, 1, 0, 0, 0, 0]])
        let evidence = index.evaluate(span(1, 1, 5, 1), in: file)
        XCTAssertEqual(evidence.kind, .directExecution)
        XCTAssertEqual(evidence.status, .uncovered)
        XCTAssertEqual(evidence.confidence, .high)
        XCTAssertEqual(evidence.executionCount, 0)
    }

    // MARK: - inferred_from_enclosing_region: matched, but not an exact span match

    func testDiffingSpanIsInferredFromEnclosingRegion() {
        // Region starts earlier than the queried branch span — e.g. a
        // switch-case region starting at the `case` label rather than the
        // branch's own statements, per SEMANTICS.md §4.
        let index = makeIndex(regions: [[1, 1, 10, 1, 3, 0, 0, 0]])
        let evidence = index.evaluate(span(2, 1, 10, 1), in: file)
        XCTAssertEqual(evidence.kind, .inferredFromEnclosingRegion)
        XCTAssertEqual(evidence.status, .covered)
        XCTAssertEqual(evidence.confidence, .medium)
        XCTAssertEqual(evidence.matchedRegionSpan, span(1, 1, 10, 1))
    }

    // MARK: - no_matching_region: file has data, nothing covers this position

    func testSpanWithNoContainedRegionIsNoMatchingRegion() {
        let index = makeIndex(regions: [[20, 1, 25, 1, 1, 0, 0, 0]])
        let evidence = index.evaluate(span(1, 1, 5, 1), in: file)
        XCTAssertEqual(evidence.kind, .noMatchingRegion)
        XCTAssertEqual(evidence.status, .unknown)
        XCTAssertEqual(evidence.confidence, .none)
    }

    // MARK: - file_not_instrumented: the file isn't in the export at all

    func testMissingFileIsFileNotInstrumented() {
        let index = makeIndex(regions: [[1, 1, 5, 1, 1, 0, 0, 0]])
        let evidence = index.evaluate(span(1, 1, 5, 1), in: "/tmp/Other.swift")
        XCTAssertEqual(evidence.kind, .fileNotInstrumented)
        XCTAssertEqual(evidence.status, .unknown)
        XCTAssertEqual(evidence.confidence, .none)
    }

    // MARK: - matching mechanics

    func testEarliestNestedRegionIsTheEntryPoint() {
        // The outer region (the branch body itself) is executed and its
        // span exactly matches the query, so this resolves as a direct
        // match; a region nested inside it (e.g. an inner if) starting
        // later must not shadow it.
        let outer = [1, 1, 10, 1, 1, 0, 0, 0]  // executed
        let nested = [3, 1, 4, 1, 0, 0, 0, 0]  // never executed
        let index = makeIndex(regions: [outer, nested])
        let evidence = index.evaluate(span(1, 1, 10, 1), in: file)
        XCTAssertEqual(evidence.kind, .directExecution)
        XCTAssertEqual(evidence.status, .covered)
    }

    func testNonCodeRegionKindIsIgnored() {
        // kind 3 == gap region; must not be treated as the branch's entry
        // point. Filtered out at decode, leaving no region at all to match —
        // the file is still "instrumented" (it has an entry, just an empty
        // one), so this is a no-match, not a not-instrumented file.
        let gapRegion = [1, 1, 2, 1, 5, 0, 0, 3]
        let index = makeIndex(regions: [gapRegion])
        let evidence = index.evaluate(span(1, 1, 10, 1), in: file)
        XCTAssertEqual(evidence.kind, .noMatchingRegion)
    }

    func testRegionFromAnExpandedFileIsIgnored() {
        // fileID 0 but expandedFileID != 0 means this region came from a
        // macro/include expansion, not the file's own source text.
        let expanded = [1, 1, 5, 1, 1, 0, 2, 0]
        let index = makeIndex(regions: [expanded])
        let evidence = index.evaluate(span(1, 1, 10, 1), in: file)
        XCTAssertEqual(evidence.kind, .noMatchingRegion)
    }
}
