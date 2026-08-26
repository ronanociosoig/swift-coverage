import XCTest

@testable import SwiftCoverageCore

final class SuggestionGeneratorTests: XCTestCase {
    private func unit(name: String = "tierName", type: String? = "Discount") -> LogicUnit {
        LogicUnit(
            name: name,
            signature: "func \(name)()",
            enclosingTypeName: type,
            filePath: "a.swift",
            location: SourcePosition(line: 1, column: 1),
            branches: []
        )
    }

    private func branch(_ kind: BranchKind, label: String) -> LogicBranch {
        LogicBranch(kind: kind, label: label, span: SourceSpan(startLine: 1, startColumn: 1, endLine: 2, endColumn: 1))
    }

    func testSwitchCaseSuggestionNamesTheQualifiedUnitAndPattern() {
        let suggestion = SuggestionGenerator.suggest(for: branch(.switchCase, label: "case .vip"), in: unit())
        XCTAssertEqual(suggestion, "Add a test calling Discount.tierName with a value matching `case .vip`.")
    }

    func testIfThenSuggestionExtractsTheCondition() {
        let suggestion = SuggestionGenerator.suggest(for: branch(.ifThen, label: "if a && b"), in: unit())
        XCTAssertEqual(suggestion, "Add a test calling Discount.tierName where `a && b` is true.")
    }

    func testIfElseSuggestionDoesNotRepeatAnUnknownCondition() {
        let suggestion = SuggestionGenerator.suggest(for: branch(.ifElse, label: "else"), in: unit())
        XCTAssertEqual(suggestion, "Add a test calling Discount.tierName where the preceding `if` condition is false.")
    }

    func testGuardElseSuggestionStripsThePrefixAndSuffix() {
        let suggestion = SuggestionGenerator.suggest(for: branch(.guardElse, label: "guard let x else"), in: unit())
        XCTAssertEqual(
            suggestion,
            "Add a test calling Discount.tierName where `let x` fails, taking the guard's `else` path."
        )
    }

    func testCatchClauseSuggestionNamesTheErrorWhenKnown() {
        let suggestion = SuggestionGenerator.suggest(for: branch(.catchClause, label: "catch NetworkError"), in: unit())
        XCTAssertEqual(suggestion, "Add a test calling Discount.tierName where the code under test throws `NetworkError`.")
    }

    func testCatchClauseSuggestionFallsBackForABareCatchAll() {
        let suggestion = SuggestionGenerator.suggest(for: branch(.catchClause, label: "catch"), in: unit())
        XCTAssertEqual(suggestion, "Add a test calling Discount.tierName where the code under test throws an error.")
    }

    func testFreeFunctionOmitsTheTypePrefix() {
        let suggestion = SuggestionGenerator.suggest(
            for: branch(.nilCoalescing, label: "?? fallback"),
            in: unit(name: "parse", type: nil)
        )
        XCTAssertEqual(suggestion, "Add a test calling parse where the left-hand side of `??` is nil.")
    }
}
