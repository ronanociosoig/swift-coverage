import XCTest

@testable import SwiftCoverageCore

/// Fast, parse-only regression coverage for the constructs `SEMANTICS.md`
/// makes explicit claims about. This reads the real fixtures in
/// `Examples/TortureTest` directly (rather than duplicating their content)
/// so there is exactly one source of truth for what those constructs look
/// like; it asserts what `LogicUnitCollector`/`BranchCollector` *detect*,
/// in well under a second and with no build/llvm-cov round trip.
///
/// This complements, rather than replaces, actually running
/// `swift-coverage` against the compiled, tested `Examples/TortureTest`
/// package — detection matching the SwiftSyntax tree is necessary but not
/// sufficient; only a real run confirms coverage *regions* still line up
/// after compilation (see `SEMANTICS.md` §9 on result builders in
/// particular, which this test file cannot speak to at all).
final class TortureFixtureDetectionTests: XCTestCase {
    private func units(_ fileName: String) throws -> [String: LogicUnit] {
        let url =
            URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // SwiftCoverageCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("Examples/TortureTest/Sources/TortureTest")
            .appendingPathComponent(fileName)
        let source = try String(contentsOf: url, encoding: .utf8)
        let result = LogicUnitCollector.collect(source: source, filePath: fileName)
        XCTAssertFalse(result.fileIsIgnored, "\(fileName) unexpectedly carries a whole-file suppression")
        return Dictionary(uniqueKeysWithValues: result.units.map { ($0.name, $0) })
    }

    // MARK: - §1 Compound conditions

    func testCompoundConditionsProduceOneObligationPerBody() throws {
        let byName = try units("CompoundConditions.swift")
        XCTAssertEqual(byName["requiresBothTrue"]?.branches.map(\.kind), [.ifThen, .ifElse])
        XCTAssertEqual(byName["requiresEitherTrue"]?.branches.map(\.kind), [.ifThen, .ifElse])
        XCTAssertEqual(byName["nestedCompound"]?.branches.map(\.kind), [.ifThen, .ifElse])
    }

    // MARK: - §2/§3 if case / guard case let

    func testIfCaseAndGuardCaseLet() throws {
        let byName = try units("PatternMatching.swift")
        XCTAssertEqual(byName["isCircle"]?.branches.map(\.kind), [.ifThen])
        XCTAssertEqual(byName["circleRadius"]?.branches.map(\.kind), [.guardElse])
    }

    // MARK: - §4 switch: where clauses, default, comma patterns

    func testSwitchWhereDefaultAndCommaPatterns() throws {
        let byName = try units("PatternMatching.swift")
        XCTAssertEqual(byName["classify"]?.branches.map(\.kind), [.switchCase, .switchCase, .switchCase])
        // Comma-separated patterns produce exactly one branch, not one per pattern.
        XCTAssertEqual(byName["isNonRectangular"]?.branches.count, 2)
        XCTAssertEqual(byName["isNonRectangular"]?.branches.map(\.kind), [.switchCase, .switchCase])
    }

    // MARK: - §5 multi-catch

    func testMultiCatchClausesAreIndependent() throws {
        let byName = try units("ErrorHandling.swift")
        XCTAssertEqual(byName["run"]?.branches.map(\.kind), [.catchClause, .catchClause, .catchClause])
    }

    // MARK: - §6 defer produces no obligation

    func testDeferProducesNoObligation() throws {
        let byName = try units("ErrorHandling.swift")
        // Only the if/else in withCleanup; the defer block contributes nothing.
        XCTAssertEqual(byName["withCleanup"]?.branches.map(\.kind), [.ifThen, .ifElse])
    }

    // MARK: - §7 while / repeat-while / for-where

    func testLoopsProduceOneObligationEach() throws {
        let byName = try units("Loops.swift")
        XCTAssertEqual(byName["countDown"]?.branches.map(\.kind), [.whileLoop])
        XCTAssertEqual(byName["repeatUntilZero"]?.branches.map(\.kind), [.repeatLoop])
        XCTAssertEqual(byName["sumEvenNumbers"]?.branches.map(\.kind), [.forLoop])
    }

    // MARK: - §8 chained ??, no obligation for ?.

    func testNilCoalescingChainIsTwoIndependentObligations() throws {
        let byName = try units("Optionals.swift")
        XCTAssertEqual(byName["firstNonNil"]?.branches.map(\.kind), [.nilCoalescing, .nilCoalescing])
        // Two distinct source lines: the outer and inner `??` are not merged into one.
        let lines = byName["firstNonNil"]?.branches.map { $0.span.start.line } ?? []
        XCTAssertEqual(Set(lines).count, 1, "both ?? sit on the same source line in the fixture")
    }

    func testOptionalChainingProducesNoObligationOfItsOwn() throws {
        let byName = try units("Optionals.swift")
        // Only the trailing ?? is an obligation; the two ?. accesses before it are not.
        XCTAssertEqual(byName["streetName"]?.branches.map(\.kind), [.nilCoalescing])
    }

    // MARK: - §9 result builder branches are detected like ordinary ones

    func testResultBuilderBranchesAreDetectedNormally() throws {
        let byName = try units("ResultBuilder.swift")
        XCTAssertEqual(byName["greeting"]?.branches.map(\.kind), [.ifThen, .ifElse, .ifThen])
    }

    // MARK: - §10 a macro invocation doesn't disturb surrounding detection

    func testMacroInvocationSiteIsSyntacticallyInert() throws {
        let byName = try units("Macros.swift")
        XCTAssertEqual(byName["describe"]?.branches.map(\.kind), [.ifThen])
    }

    // MARK: - §11 #if produces no obligation; content inside is still walked

    func testConditionalCompilationProducesNoObligationOfItsOwn() throws {
        let byName = try units("ConditionalCompilation.swift")
        // platformName has no runtime branches at all: every path is a plain
        // return, one per #if/#elseif/#else clause, so it's not even a logic unit.
        XCTAssertNil(byName["platformName"])
        // The if inside the #if os(macOS) clause is still detected normally.
        XCTAssertEqual(byName["describeCount"]?.branches.map(\.kind), [.ifThen])
    }

    // MARK: - §12 if #available is an ordinary if/else

    func testAvailabilityConditionIsOrdinaryIfElse() throws {
        let byName = try units("ConditionalCompilation.swift")
        XCTAssertEqual(byName["modernAPIDescription"]?.branches.map(\.kind), [.ifThen, .ifElse])
    }
}
