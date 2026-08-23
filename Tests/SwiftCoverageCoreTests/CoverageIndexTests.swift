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

    func testCoveredRegionReturnsTrue() {
        let index = makeIndex(regions: [[1, 1, 5, 1, 1, 0, 0, 0]])
        XCTAssertEqual(index.isCovered(span(1, 1, 5, 1), in: file), true)
    }

    func testUncoveredRegionReturnsFalse() {
        let index = makeIndex(regions: [[1, 1, 5, 1, 0, 0, 0, 0]])
        XCTAssertEqual(index.isCovered(span(1, 1, 5, 1), in: file), false)
    }

    func testMissingFileReturnsNil() {
        let index = makeIndex(regions: [[1, 1, 5, 1, 1, 0, 0, 0]])
        XCTAssertNil(index.isCovered(span(1, 1, 5, 1), in: "/tmp/Other.swift"))
    }

    func testSpanWithNoContainedRegionReturnsNil() {
        let index = makeIndex(regions: [[20, 1, 25, 1, 1, 0, 0, 0]])
        XCTAssertNil(index.isCovered(span(1, 1, 5, 1), in: file))
    }

    func testEarliestNestedRegionIsTheEntryPoint() {
        // The outer region (the branch body itself) is executed; a region
        // nested inside it (e.g. an inner if) starting later must not shadow it.
        let outer = [1, 1, 10, 1, 1, 0, 0, 0]  // executed
        let nested = [3, 1, 4, 1, 0, 0, 0, 0]  // never executed
        let index = makeIndex(regions: [outer, nested])
        XCTAssertEqual(index.isCovered(span(1, 1, 10, 1), in: file), true)
    }

    func testNonCodeRegionKindIsIgnored() {
        // kind 3 == gap region; must not be treated as the branch's entry point.
        let gapRegion = [1, 1, 2, 1, 5, 0, 0, 3]
        let index = makeIndex(regions: [gapRegion])
        XCTAssertNil(index.isCovered(span(1, 1, 10, 1), in: file))
    }

    func testRegionFromAnExpandedFileIsIgnored() {
        // fileID 0 but expandedFileID != 0 means this region came from a
        // macro/include expansion, not the file's own source text.
        let expanded = [1, 1, 5, 1, 1, 0, 2, 0]
        let index = makeIndex(regions: [expanded])
        XCTAssertNil(index.isCovered(span(1, 1, 10, 1), in: file))
    }
}
