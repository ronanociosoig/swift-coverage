import Foundation

/// Runs `swift test --enable-code-coverage` for a package and locates the
/// resulting coverage export JSON.
///
/// Two separate `swift test` invocations are used deliberately: the first
/// (whose output is streamed live) actually runs the suite and drives
/// coverage instrumentation; `--show-codecov-path` only prints the path
/// SwiftPM wrote the export to, without re-running anything.
///
/// Only plain SwiftPM packages can be tested this way. A package that's
/// iOS-only, or otherwise can't be built by a bare `swift test` on macOS,
/// needs `XcodeCoverageRunner` instead.
public struct CoverageRunner {
    public var packagePath: String
    public var extraTestArguments: [String]
    public var swiftExecutable: String

    public init(packagePath: String, extraTestArguments: [String] = [], swiftExecutable: String = "swift") {
        self.packagePath = packagePath
        self.extraTestArguments = extraTestArguments
        self.swiftExecutable = swiftExecutable
    }

    public struct Result {
        public var testsPassed: Bool
        public var coverageJSONPath: String?
    }

    public func run(streamOutput: Bool = true) throws -> Result {
        let testRun = try ProcessRunner.run(
            tool: swiftExecutable,
            arguments: ["test", "--enable-code-coverage"] + extraTestArguments,
            currentDirectory: URL(fileURLWithPath: packagePath),
            streamOutput: streamOutput
        )
        return Result(testsPassed: testRun.exitCode == 0, coverageJSONPath: try discoverCoverageJSONPath())
    }

    /// Asks SwiftPM where it last wrote (or would write) the coverage export
    /// JSON, without running the test suite. Used for `--skip-tests`, and
    /// internally by `run()` right after a fresh test run.
    public func discoverCoverageJSONPath() throws -> String? {
        let pathRun = try ProcessRunner.run(
            tool: swiftExecutable,
            arguments: ["test", "--show-codecov-path"],
            currentDirectory: URL(fileURLWithPath: packagePath),
            streamOutput: false
        )
        let path = pathRun.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }
}
