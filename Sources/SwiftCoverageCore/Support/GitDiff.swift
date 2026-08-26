import Foundation

/// Computes which lines changed relative to a git ref — the mechanism
/// behind `--diff-base`, letting swift-coverage flag only *new or changed*
/// uncovered logic instead of every pre-existing gap in a codebase adopting
/// it for the first time.
public enum GitDiff {
    /// Per-file (absolute path), the 1-based line numbers that are new or
    /// modified in the working tree relative to the merge-base of `base`
    /// and `HEAD` — i.e. exactly the lines a PR opened against `base` would
    /// show as added, regardless of commits landed on `base` since the
    /// branch diverged. This is `git diff base...HEAD` semantics (three-dot,
    /// merge-base) rather than a direct two-ref diff, extended to the
    /// working tree so uncommitted changes are included too.
    public static func changedLines(packagePath: String, base: String) throws -> [String: Set<Int>] {
        let repoRoot = try repositoryRoot(packagePath: packagePath)

        let mergeBaseRun = try ProcessRunner.run(
            tool: "git",
            arguments: ["merge-base", base, "HEAD"],
            currentDirectory: URL(fileURLWithPath: packagePath),
            streamOutput: false
        )
        guard mergeBaseRun.exitCode == 0 else {
            throw SwiftCoverageError.usage(
                "Could not find a merge base between '\(base)' and HEAD: \(mergeBaseRun.stderr.trimmingCharacters(in: .whitespacesAndNewlines))"
            )
        }
        let mergeBase = mergeBaseRun.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        let diffRun = try ProcessRunner.run(
            tool: "git",
            arguments: ["diff", "--unified=0", "--no-color", mergeBase],
            currentDirectory: URL(fileURLWithPath: packagePath),
            streamOutput: false
        )
        guard diffRun.exitCode == 0 else {
            throw SwiftCoverageError.usage(
                "git diff against '\(base)' (merge-base \(mergeBase)) failed: "
                    + diffRun.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        return parse(diffRun.stdout, repoRoot: repoRoot)
    }

    private static func repositoryRoot(packagePath: String) throws -> URL {
        let run = try ProcessRunner.run(
            tool: "git",
            arguments: ["rev-parse", "--show-toplevel"],
            currentDirectory: URL(fileURLWithPath: packagePath),
            streamOutput: false
        )
        guard run.exitCode == 0 else {
            throw SwiftCoverageError.usage(
                "'\(packagePath)' does not look like a git repository: "
                    + run.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return URL(fileURLWithPath: run.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// A unified diff with `--unified=0` has no context lines: every hunk's
    /// `+newStart,newCount` describes exactly the lines added or modified in
    /// the new file version, with no need to walk individual `+`/`-` lines
    /// or track a running counter.
    private static func parse(_ diffText: String, repoRoot: URL) -> [String: Set<Int>] {
        var changed: [String: Set<Int>] = [:]
        var currentFile: String?

        for line in diffText.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("+++ ") {
                currentFile = resolvedPath(fromDiffHeader: String(line.dropFirst(4)), repoRoot: repoRoot)
            } else if line.hasPrefix("@@"), let currentFile {
                if let range = parseHunkHeader(String(line)) {
                    changed[currentFile, default: []].formUnion(range)
                }
            }
        }
        return changed
    }

    /// `"+++ b/relative/path.swift"` -> absolute path under `repoRoot`;
    /// `"+++ /dev/null"` (a deleted file) -> `nil`, since a deletion can't
    /// contain new lines to require coverage of.
    private static func resolvedPath(fromDiffHeader header: String, repoRoot: URL) -> String? {
        guard header != "/dev/null" else { return nil }
        let relative = header.hasPrefix("b/") ? String(header.dropFirst(2)) : header
        return URL(fileURLWithPath: relative, relativeTo: repoRoot).standardizedFileURL.path
    }

    /// Parses `"@@ -oldStart[,oldCount] +newStart[,newCount] @@ ..."`,
    /// returning the new-file line range it describes. A count is omitted
    /// entirely when it's 1; an explicit `,0` means a pure deletion at this
    /// position, contributing no new lines.
    private static func parseHunkHeader(_ line: String) -> ClosedRange<Int>? {
        let parts = line.split(separator: " ")
        guard let newPart = parts.first(where: { $0.hasPrefix("+") }) else { return nil }
        let token = newPart.dropFirst()
        let numbers = token.split(separator: ",")
        guard let start = numbers.first.flatMap({ Int($0) }) else { return nil }
        let count = numbers.count > 1 ? (Int(numbers[1]) ?? 1) : 1
        guard count > 0 else { return nil }
        return start...(start + count - 1)
    }
}
