import XCTest

@testable import SwiftCoverageCore

final class LogicUnitCollectorTests: XCTestCase {
    private func fixture(_ name: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testPlainDataProducesNoLogicUnits() throws {
        let source = try fixture("PlainData.swift")
        let result = LogicUnitCollector.collect(source: source, filePath: "PlainData.swift")
        XCTAssertFalse(result.fileIsIgnored)
        XCTAssertTrue(result.units.isEmpty, "a struct with only stored properties should never become a LogicUnit")
    }

    func testBranchCountsForEachConstruct() throws {
        let source = try fixture("Logic.swift")
        let result = LogicUnitCollector.collect(source: source, filePath: "Logic.swift")
        let byName = Dictionary(uniqueKeysWithValues: result.units.map { ($0.name, $0) })

        XCTAssertEqual(byName["classify"]?.branches.map(\.kind), [.ifThen, .ifThen, .ifElse])
        XCTAssertEqual(byName["guarded"]?.branches.map(\.kind), [.guardElse])
        XCTAssertEqual(byName["switcher"]?.branches.map(\.kind), [.switchCase, .switchCase, .switchCase])
        XCTAssertEqual(byName["looped"]?.branches.map(\.kind), [.forLoop])
        XCTAssertEqual(byName["spun"]?.branches.map(\.kind), [.whileLoop])
        XCTAssertEqual(byName["repeated"]?.branches.map(\.kind), [.repeatLoop])
        XCTAssertEqual(byName["caught"]?.branches.map(\.kind), [.catchClause])
        XCTAssertEqual(byName["ternary"]?.branches.map(\.kind), [.ternaryThen, .ternaryElse])
        XCTAssertEqual(byName["fallback"]?.branches.map(\.kind), [.nilCoalescing])

        XCTAssertEqual(byName["classify"]?.cyclomaticComplexity, 4)
        XCTAssertEqual(byName["classify"]?.enclosingTypeName, "Logic")
    }

    /// Regression test: a shorthand (getter-only) computed property — the
    /// shape of every SwiftUI `body` — must report its branches at their
    /// real source lines, not at positions relative to some synthetic
    /// wrapper. See `BranchCollector.collect`'s doc comment.
    func testShorthandComputedPropertyReportsRealLineNumbers() throws {
        let source = try fixture("Logic.swift")
        let result = LogicUnitCollector.collect(source: source, filePath: "Logic.swift")
        let byName = Dictionary(uniqueKeysWithValues: result.units.map { ($0.name, $0) })

        let unit = try XCTUnwrap(byName["describedState"])
        XCTAssertEqual(unit.branches.map(\.kind), [.switchCase, .switchCase])
        XCTAssertEqual(unit.branches.map { $0.span.start.line }, [90, 92])
    }

    func testIgnoreFileExcludesEverything() throws {
        let source = try fixture("IgnoredFile.swift")
        let result = LogicUnitCollector.collect(source: source, filePath: "IgnoredFile.swift")
        XCTAssertTrue(result.fileIsIgnored)
        XCTAssertTrue(result.units.isEmpty)
    }

    func testIgnoreSuppressesWholeDeclaration() throws {
        let source = try fixture("Suppressed.swift")
        let result = LogicUnitCollector.collect(source: source, filePath: "Suppressed.swift")
        let byName = Dictionary(uniqueKeysWithValues: result.units.map { ($0.name, $0) })

        let entirelyIgnored = try XCTUnwrap(byName["entirelyIgnored"])
        XCTAssertTrue(entirelyIgnored.isSuppressed)
        XCTAssertTrue(entirelyIgnored.requiredBranches.isEmpty)

        let partiallyIgnored = try XCTUnwrap(byName["partiallyIgnored"])
        XCTAssertFalse(partiallyIgnored.isSuppressed)
        XCTAssertEqual(partiallyIgnored.branches.count, 1)
        XCTAssertTrue(partiallyIgnored.branches[0].isSuppressed)
        XCTAssertTrue(partiallyIgnored.requiredBranches.isEmpty)
    }
}
