import ArgumentParser
import Foundation
import SwiftCoverageCore

@main
struct SwiftCoverageCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift-coverage",
        abstract: "Requires every branch of a Swift package's logic to be exercised by its test suite.",
        discussion: """
            Unlike a line/statement coverage percentage, swift-coverage checks each individual \
            branch of your code's logic \u{2014} every if/else, guard, switch case, loop, catch \
            clause, and ternary/?? alternative \u{2014} and fails if any of them was never reached \
            by `swift test`. A percentage can hide one critical, never-exercised path behind a lot \
            of well-tested boilerplate; this doesn't.

            Plain data types need no special treatment: a declaration with no branching logic \
            (a stored property, a struct's memberwise fields) is never required to be covered \
            in the first place, because it never becomes a logic unit to begin with.

            Mark an intentionally-untested declaration or branch with a comment:
              // swift-coverage:ignore          (directly above a func/init/property)
              // swift-coverage:ignore-branch   (directly above an if/guard/case/catch/loop, \
            or above the statement containing a ternary/??)
              // swift-coverage:ignore-file     (as the first line of a file)
            """,
        version: SwiftCoverageVersion.current
    )

    @Argument(help: "Path to the Swift package to analyze.")
    var path: String = "."

    @Option(help: "Output format: text or json.")
    var format: OutputFormat = .text

    @Flag(help: "Reuse an existing coverage export instead of running `swift test` again.")
    var skipTests: Bool = false

    @Option(help: "Coverage export JSON to use with --skip-tests, instead of asking SwiftPM for its path.")
    var coverageJson: String?

    @Option(help: "Glob (relative to the package root) to restrict analysis to. Repeatable.")
    var include: [String] = []

    @Option(help: "Glob (relative to the package root) to exclude from analysis. Repeatable.")
    var exclude: [String] = []

    @Option(
        name: .customLong("filter"),
        help: "Passed through to `swift test --filter` (or, with --scheme, to `xcodebuild -only-testing:`)."
    )
    var testFilter: String?

    @Option(
        help: """
            Xcode scheme to test via `xcodebuild` instead of `swift test` \u{2014} for a package that's iOS-only \
            or otherwise can't be built by a bare `swift test` on macOS. Requires --destination.
            """
    )
    var scheme: String?

    @Option(help: "xcodebuild destination, e.g. 'platform=iOS Simulator,name=iPhone 17'. Required with --scheme.")
    var destination: String?

    @Option(help: "Explicit .xcodeproj path, passed to xcodebuild -project. Omit to let xcodebuild auto-detect.")
    var xcodeProject: String?

    @Option(help: "Explicit .xcworkspace path, passed to xcodebuild -workspace.")
    var xcodeWorkspace: String?

    @Option(
        help: """
            Derived data path for a --scheme run, so its Coverage.profdata can be found afterward. Defaults to \
            <path>/.build/swift-coverage-xcode.
            """
    )
    var derivedDataPath: String?

    @Option(
        help: """
            Only require coverage for logic added or changed since this git ref (e.g. 'origin/main'), \
            computed against their merge-base so commits landed on the ref afterward don't count. Lets an \
            existing, previously-untested codebase adopt swift-coverage without every pre-existing gap \
            failing the check at once \u{2014} exactly what a PR check wants.
            """
    )
    var diffBase: String?

    @Flag(help: "Report uncovered logic paths without failing the command.")
    var noFail: Bool = false

    @Flag(help: "Also list files that had no branching logic (and so needed no coverage).")
    var verbose: Bool = false

    enum OutputFormat: String, ExpressibleByArgument {
        case text
        case json
    }

    func run() throws {
        let analyzer = SwiftCoverageAnalyzer(packagePath: path, include: include, exclude: exclude)

        var report: AnalysisReport
        do {
            if skipTests {
                guard let jsonPath = try coverageJson ?? analyzer.discoverExistingCoverageJSONPath() else {
                    throw SwiftCoverageError.coverageDataUnavailable
                }
                report = try analyzer.analyzeUsingExistingCoverage(jsonPath: jsonPath)
            } else if let scheme {
                guard let destination else {
                    throw SwiftCoverageError.usage(
                        "--destination is required with --scheme, e.g. 'platform=iOS Simulator,name=iPhone 17'. "
                            + "List available simulators with `xcrun simctl list devices available`."
                    )
                }
                report = try analyzer.analyzeWithFreshXcodeTestRun(
                    scheme: scheme,
                    destination: destination,
                    project: xcodeProject,
                    workspace: xcodeWorkspace,
                    derivedDataPath: derivedDataPath,
                    onlyTesting: testFilter.map { [$0] } ?? []
                )
            } else {
                var extraArgs: [String] = []
                if let testFilter { extraArgs += ["--filter", testFilter] }
                report = try analyzer.analyzeWithFreshTestRun(extraTestArguments: extraArgs)
            }
            if let diffBase {
                let changedLines = try GitDiff.changedLines(packagePath: path, base: diffBase)
                report = report.scopedToChangedLines(changedLines, diffBase: diffBase)
            }
        } catch let error as SwiftCoverageError {
            FileHandle.standardError.write(Data(((error.errorDescription ?? "Unknown error") + "\n").utf8))
            if case .testsFailed = error {
                throw ExitCode(2)
            }
            throw ExitCode(3)
        }

        switch format {
        case .text:
            print(TextReporter.render(report, verbose: verbose))
        case .json:
            print(try JSONReporter.render(report))
        }

        if !report.passes, !noFail {
            throw ExitCode(1)
        }
    }
}
