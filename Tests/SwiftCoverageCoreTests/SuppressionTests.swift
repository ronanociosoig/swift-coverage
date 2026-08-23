import SwiftSyntax
import XCTest

@testable import SwiftCoverageCore

final class SuppressionTests: XCTestCase {
    func testExactMarkerMatches() {
        let trivia = Trivia(pieces: [.lineComment("// swift-coverage:ignore")])
        XCTAssertTrue(Suppression.containsIgnore(trivia))
        XCTAssertFalse(Suppression.containsIgnoreBranch(trivia))
    }

    func testIgnoreBranchIsNotConfusedWithIgnore() {
        // "ignore" is a prefix of "ignore-branch"; the match must be exact,
        // not prefix-based, so these two directives can't bleed into each other.
        let trivia = Trivia(pieces: [.lineComment("// swift-coverage:ignore-branch")])
        XCTAssertFalse(Suppression.containsIgnore(trivia))
        XCTAssertTrue(Suppression.containsIgnoreBranch(trivia))
    }

    func testDocCommentsAreNotDirectives() {
        let trivia = Trivia(pieces: [.docLineComment("/// swift-coverage:ignore")])
        XCTAssertFalse(Suppression.containsIgnore(trivia))
    }

    func testUnrelatedCommentsDoNotMatch() {
        let trivia = Trivia(pieces: [.lineComment("// TODO: fix this")])
        XCTAssertFalse(Suppression.containsIgnore(trivia))
        XCTAssertFalse(Suppression.containsIgnoreBranch(trivia))
    }

    func testSurroundingWhitespaceIsTolerated() {
        let trivia = Trivia(pieces: [.lineComment("//   swift-coverage:ignore   ")])
        XCTAssertTrue(Suppression.containsIgnore(trivia))
    }

    func testFileIgnoreOnlyLooksAtTheFileStart() throws {
        let source = """
            // swift-coverage:ignore-file
            struct S {
                func f(_ n: Int) -> Int { n < 0 ? -n : n }
            }
            """
        let (units, ignored) = LogicUnitCollector.collect(source: source, filePath: "F.swift")
        XCTAssertTrue(ignored)
        XCTAssertTrue(units.isEmpty)
    }

    func testFileIgnoreDoesNotApplyMidFile() throws {
        let source = """
            struct S {
                // swift-coverage:ignore-file
                func f(_ n: Int) -> Int { n < 0 ? -n : n }
            }
            """
        let (units, ignored) = LogicUnitCollector.collect(source: source, filePath: "F.swift")
        XCTAssertFalse(ignored)
        XCTAssertFalse(units.isEmpty)
    }
}
