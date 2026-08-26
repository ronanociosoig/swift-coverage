import MCP
import SwiftCoverageCore

/// Shared argument parsing and report-building for the tools that need a
/// coverage run (`check_coverage`, `list_uncovered_branches`).
enum CoverageRequest {
    struct Arguments {
        var path: String
        var include: [String]
        var exclude: [String]
        var skipTests: Bool
        var testFilter: String?
        var scheme: String?
        var destination: String?
        var xcodeProject: String?
        var xcodeWorkspace: String?
        var derivedDataPath: String?
        var diffBase: String?
    }

    static func parse(_ arguments: [String: Value]?) -> Arguments? {
        guard let path = ParamExtractor.string("path", from: arguments) else { return nil }
        return Arguments(
            path: path,
            include: ParamExtractor.stringArray("include", from: arguments) ?? [],
            exclude: ParamExtractor.stringArray("exclude", from: arguments) ?? [],
            skipTests: ParamExtractor.bool("skip_tests", from: arguments),
            testFilter: ParamExtractor.string("test_filter", from: arguments),
            scheme: ParamExtractor.string("scheme", from: arguments),
            destination: ParamExtractor.string("destination", from: arguments),
            xcodeProject: ParamExtractor.string("xcode_project", from: arguments),
            xcodeWorkspace: ParamExtractor.string("xcode_workspace", from: arguments),
            derivedDataPath: ParamExtractor.string("derived_data_path", from: arguments),
            diffBase: ParamExtractor.string("diff_base", from: arguments)
        )
    }

    static func buildReport(_ args: Arguments) throws -> AnalysisReport {
        let analyzer = SwiftCoverageAnalyzer(packagePath: args.path, include: args.include, exclude: args.exclude)
        let report = try buildUnscopedReport(args, analyzer: analyzer)

        guard let diffBase = args.diffBase else { return report }
        let changedLines = try GitDiff.changedLines(packagePath: args.path, base: diffBase)
        return report.scopedToChangedLines(changedLines, diffBase: diffBase)
    }

    private static func buildUnscopedReport(_ args: Arguments, analyzer: SwiftCoverageAnalyzer) throws
        -> AnalysisReport
    {
        if args.skipTests {
            guard let jsonPath = try analyzer.discoverExistingCoverageJSONPath() else {
                throw SwiftCoverageError.coverageDataUnavailable
            }
            return try analyzer.analyzeUsingExistingCoverage(jsonPath: jsonPath)
        }

        // Never stream the test run's own output here: it would interleave
        // with (and corrupt) the JSON-RPC traffic on stdout the MCP
        // transport depends on. Serialized: concurrent tool calls must not
        // run a test suite against the same package's build state at once.
        if let scheme = args.scheme {
            guard let destination = args.destination else {
                throw SwiftCoverageError.usage("'destination' is required when 'scheme' is set.")
            }
            return try CoverageRunGate.shared.run {
                try analyzer.analyzeWithFreshXcodeTestRun(
                    scheme: scheme,
                    destination: destination,
                    project: args.xcodeProject,
                    workspace: args.xcodeWorkspace,
                    derivedDataPath: args.derivedDataPath,
                    onlyTesting: args.testFilter.map { [$0] } ?? [],
                    streamTestOutput: false
                )
            }
        }

        var extraArgs: [String] = []
        if let filter = args.testFilter { extraArgs += ["--filter", filter] }
        return try CoverageRunGate.shared.run {
            try analyzer.analyzeWithFreshTestRun(extraTestArguments: extraArgs, streamTestOutput: false)
        }
    }
}
