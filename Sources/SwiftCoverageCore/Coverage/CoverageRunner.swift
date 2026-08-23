import Foundation

/// Runs `swift test --enable-code-coverage` for a package and locates the
/// resulting coverage export JSON.
///
/// Two separate `swift test` invocations are used deliberately: the first
/// (whose output is streamed live) actually runs the suite and drives
/// coverage instrumentation; `--show-codecov-path` only prints the path
/// SwiftPM wrote the export to, without re-running anything.
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
        let testRun = try runProcess(
            arguments: ["test", "--enable-code-coverage"] + extraTestArguments,
            streamOutput: streamOutput
        )
        return Result(testsPassed: testRun.exitCode == 0, coverageJSONPath: try discoverCoverageJSONPath())
    }

    /// Asks SwiftPM where it last wrote (or would write) the coverage export
    /// JSON, without running the test suite. Used for `--skip-tests`, and
    /// internally by `run()` right after a fresh test run.
    public func discoverCoverageJSONPath() throws -> String? {
        let pathRun = try runProcess(arguments: ["test", "--show-codecov-path"], streamOutput: false)
        let path = pathRun.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    @discardableResult
    private func runProcess(arguments: [String], streamOutput: Bool) throws -> (exitCode: Int32, stdout: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [swiftExecutable] + arguments
        process.currentDirectoryURL = URL(fileURLWithPath: packagePath)

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = streamOutput ? stdoutPipe : Pipe()

        var collected = Data()
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            collected.append(chunk)
            if streamOutput {
                FileHandle.standardOutput.write(chunk)
            }
        }

        try process.run()
        process.waitUntilExit()
        stdoutPipe.fileHandleForReading.readabilityHandler = nil

        let output = String(data: collected, encoding: .utf8) ?? ""
        return (process.terminationStatus, output)
    }
}
