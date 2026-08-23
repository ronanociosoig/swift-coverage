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
    }

    static func parse(_ arguments: [String: Value]?) -> Arguments? {
        guard let path = ParamExtractor.string("path", from: arguments) else { return nil }
        return Arguments(
            path: path,
            include: ParamExtractor.stringArray("include", from: arguments) ?? [],
            exclude: ParamExtractor.stringArray("exclude", from: arguments) ?? [],
            skipTests: ParamExtractor.bool("skip_tests", from: arguments),
            testFilter: ParamExtractor.string("test_filter", from: arguments)
        )
    }

    static func buildReport(_ args: Arguments) throws -> AnalysisReport {
        let analyzer = SwiftCoverageAnalyzer(packagePath: args.path, include: args.include, exclude: args.exclude)
        if args.skipTests {
            guard let jsonPath = try analyzer.discoverExistingCoverageJSONPath() else {
                throw SwiftCoverageError.coverageDataUnavailable
            }
            return try analyzer.analyzeUsingExistingCoverage(jsonPath: jsonPath)
        }
        // Never stream `swift test`'s own output here: it would interleave
        // with (and corrupt) the JSON-RPC traffic on stdout the MCP
        // transport depends on.
        var extraArgs: [String] = []
        if let filter = args.testFilter { extraArgs += ["--filter", filter] }
        // Serialized: concurrent tool calls must not run `swift test`
        // against the same package's `.build` at the same time.
        return try CoverageRunGate.shared.run {
            try analyzer.analyzeWithFreshTestRun(extraTestArguments: extraArgs, streamTestOutput: false)
        }
    }
}
