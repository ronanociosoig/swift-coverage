import Foundation

/// Orchestrates a full `swift-coverage` run: discover source files, collect
/// logic units, run (or reuse) coverage data, and cross-reference the two
/// into an `AnalysisReport`.
public struct SwiftCoverageAnalyzer {
    public var packagePath: String
    public var include: [String]
    public var exclude: [String]

    public init(packagePath: String, include: [String] = [], exclude: [String] = []) {
        self.packagePath = packagePath
        self.include = include
        self.exclude = exclude
    }

    /// Parses every discovered source file and collects its logic units,
    /// without running tests or requiring coverage data.
    public func collectLogicUnits() throws -> (units: [LogicUnit], filesWithoutLogic: [String]) {
        let files = try FileDiscovery.sourceFiles(packagePath: packagePath, include: include, exclude: exclude)
        var units: [LogicUnit] = []
        var filesWithoutLogic: [String] = []
        for file in files {
            guard let source = try? String(contentsOfFile: file, encoding: .utf8) else { continue }
            let result = LogicUnitCollector.collect(source: source, filePath: file)
            if result.fileIsIgnored { continue }
            if result.units.isEmpty {
                filesWithoutLogic.append(file)
            } else {
                units.append(contentsOf: result.units)
            }
        }
        return (units, filesWithoutLogic)
    }

    /// Cross-references already-collected logic units against a coverage
    /// index, filling in each branch's `isCovered`.
    func resolveCoverage(units: [LogicUnit], using index: CoverageIndex) -> [LogicUnit] {
        units.map { unit in
            var unit = unit
            unit.branches = unit.branches.map { branch in
                var branch = branch
                branch.isCovered = index.isCovered(branch.span, in: unit.filePath)
                return branch
            }
            return unit
        }
    }

    /// Runs `swift test --enable-code-coverage`, then builds the full report.
    /// Throws `SwiftCoverageError.testsFailed` if the suite failed, and
    /// `.coverageDataUnavailable` if no coverage export could be found even
    /// though the tests ran.
    public func analyzeWithFreshTestRun(
        extraTestArguments: [String] = [],
        streamTestOutput: Bool = true
    ) throws -> AnalysisReport {
        let runner = CoverageRunner(packagePath: packagePath, extraTestArguments: extraTestArguments)
        let result = try runner.run(streamOutput: streamTestOutput)
        guard result.testsPassed else { throw SwiftCoverageError.testsFailed }
        guard let path = result.coverageJSONPath else { throw SwiftCoverageError.coverageDataUnavailable }
        return try analyzeUsingExistingCoverage(jsonPath: path)
    }

    /// Asks SwiftPM where it last wrote the coverage export JSON, without
    /// running the test suite. Used for `--skip-tests`.
    public func discoverExistingCoverageJSONPath() throws -> String? {
        try CoverageRunner(packagePath: packagePath).discoverCoverageJSONPath()
    }

    /// Builds the report from a previously produced coverage export JSON,
    /// without invoking `swift test` again (`--skip-tests`).
    public func analyzeUsingExistingCoverage(jsonPath: String) throws -> AnalysisReport {
        let index: CoverageIndex
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
            let export = try JSONDecoder().decode(CoverageExport.self, from: data)
            index = CoverageIndex(export: export)
        } catch {
            throw SwiftCoverageError.coverageDecodeFailed(underlying: error)
        }

        let (rawUnits, filesWithoutLogic) = try collectLogicUnits()
        let resolvedUnits = resolveCoverage(units: rawUnits, using: index)
        return AnalysisReport(packagePath: packagePath, units: resolvedUnits, filesWithoutLogic: filesWithoutLogic)
    }
}
