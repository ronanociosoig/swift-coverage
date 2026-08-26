import XCTest

@testable import SwiftCoverageCore

/// Exercises `GitDiff.changedLines` against a real, throwaway git repository
/// rather than hand-crafted diff text — the whole point of this feature is
/// parsing whatever `git diff --unified=0` actually emits, and that's the
/// thing worth verifying directly.
final class GitDiffTests: XCTestCase {
    private var repoPath: String!

    override func setUpWithError() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("swift-coverage-gitdiff-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        repoPath = dir.path

        try run("git", ["init", "-q"])
        try run("git", ["-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "--allow-empty", "-q", "-m", "init"])
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: repoPath)
    }

    @discardableResult
    private func run(_ tool: String, _ arguments: [String]) throws -> String {
        let result = try ProcessRunner.run(
            tool: tool, arguments: arguments, currentDirectory: URL(fileURLWithPath: repoPath), streamOutput: false)
        XCTAssertEqual(result.exitCode, 0, "\(tool) \(arguments.joined(separator: " ")) failed: \(result.stderr)")
        return result.stdout
    }

    private func write(_ relativePath: String, _ content: String) throws {
        let url = URL(fileURLWithPath: repoPath).appendingPathComponent(relativePath)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    func testNewFileReportsEveryLineAsChanged() throws {
        try write("New.swift", "line1\nline2\nline3\n")
        try run("git", ["add", "-A"])

        let changed = try GitDiff.changedLines(packagePath: repoPath, base: "HEAD")

        let path = URL(fileURLWithPath: repoPath).appendingPathComponent("New.swift").standardizedFileURL.path
        XCTAssertEqual(changed[path], [1, 2, 3])
    }

    func testModifiedFileReportsOnlyTheChangedLines() throws {
        try write("Existing.swift", "line1\nline2\nline3\nline4\nline5\n")
        try run("git", ["add", "-A"])
        try run("git", ["-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "-q", "-m", "add file"])

        try write("Existing.swift", "line1\nCHANGED\nline3\nline4\nline5\n")

        let changed = try GitDiff.changedLines(packagePath: repoPath, base: "HEAD")

        let path = URL(fileURLWithPath: repoPath).appendingPathComponent("Existing.swift").standardizedFileURL.path
        XCTAssertEqual(changed[path], [2])
    }

    func testUnrelatedUnmodifiedFileIsAbsent() throws {
        try write("A.swift", "a\n")
        try write("B.swift", "b\n")
        try run("git", ["add", "-A"])
        try run("git", ["-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "-q", "-m", "add both"])

        try write("A.swift", "a-changed\n")

        let changed = try GitDiff.changedLines(packagePath: repoPath, base: "HEAD")

        let bPath = URL(fileURLWithPath: repoPath).appendingPathComponent("B.swift").standardizedFileURL.path
        XCTAssertNil(changed[bPath])
    }

    func testPureDeletionContributesNoChangedLines() throws {
        try write("ToDelete.swift", "a\nb\nc\n")
        try write("Keep.swift", "keep\n")
        try run("git", ["add", "-A"])
        try run("git", ["-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "-q", "-m", "add"])

        try FileManager.default.removeItem(
            at: URL(fileURLWithPath: repoPath).appendingPathComponent("ToDelete.swift"))

        let changed = try GitDiff.changedLines(packagePath: repoPath, base: "HEAD")

        let deletedPath = URL(fileURLWithPath: repoPath).appendingPathComponent("ToDelete.swift").standardizedFileURL
            .path
        XCTAssertNil(changed[deletedPath])
    }

    func testMergeBaseSemanticsIgnoreCommitsLandedOnBaseAfterDivergence() throws {
        // main: commit A
        try write("Shared.swift", "original\n")
        try run("git", ["add", "-A"])
        try run("git", ["-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "-q", "-m", "A"])
        try run("git", ["branch", "-q", "feature"])

        // main moves forward with commit B, touching a file the feature
        // branch never sees.
        try write("MainOnly.swift", "only on main\n")
        try run("git", ["add", "-A"])
        try run("git", ["-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "-q", "-m", "B"])

        // Switch to the feature branch (based on A) and make its own change.
        try run("git", ["checkout", "-q", "feature"])
        try write("Feature.swift", "feature work\n")
        try run("git", ["add", "-A"])
        try run(
            "git", ["-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "-q", "-m", "feature work"])

        let changed = try GitDiff.changedLines(packagePath: repoPath, base: "main")

        let featurePath = URL(fileURLWithPath: repoPath).appendingPathComponent("Feature.swift").standardizedFileURL
            .path
        let mainOnlyPath = URL(fileURLWithPath: repoPath).appendingPathComponent("MainOnly.swift")
            .standardizedFileURL.path
        XCTAssertEqual(changed[featurePath], [1])
        XCTAssertNil(changed[mainOnlyPath], "commit B landed on main after the branch point shouldn't show up as a feature-branch change")
    }
}
