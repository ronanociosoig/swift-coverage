import Foundation

/// Runs an executable and captures its output.
///
/// Both stdout and stderr are always drained via a readability handler, even
/// when their content isn't forwarded anywhere: an unread pipe makes the
/// child block on its next write once the OS pipe buffer fills — which
/// `swift test`'s and `xcodebuild`'s build output routinely does — hanging
/// `waitUntilExit()` right along with it. Shared by `CoverageRunner` and
/// `XcodeCoverageRunner` so this fix lives in exactly one place.
enum ProcessRunner {
    struct Output {
        var exitCode: Int32
        var stdout: String
        var stderr: String
    }

    @discardableResult
    static func run(
        executableURL: URL,
        arguments: [String],
        currentDirectory: URL? = nil,
        streamOutput: Bool
    ) throws -> Output {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        if let currentDirectory {
            process.currentDirectoryURL = currentDirectory
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var collectedOut = Data()
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            collectedOut.append(chunk)
            if streamOutput {
                FileHandle.standardOutput.write(chunk)
            }
        }
        var collectedErr = Data()
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            collectedErr.append(chunk)
            if streamOutput {
                FileHandle.standardError.write(chunk)
            }
        }

        try process.run()
        process.waitUntilExit()
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        return Output(
            exitCode: process.terminationStatus,
            stdout: String(data: collectedOut, encoding: .utf8) ?? "",
            stderr: String(data: collectedErr, encoding: .utf8) ?? ""
        )
    }

    /// Convenience for invoking a named tool (resolved via `/usr/bin/env`,
    /// so it's found on `PATH` the same way a shell would find it) rather
    /// than an absolute executable URL.
    @discardableResult
    static func run(
        tool: String,
        arguments: [String],
        currentDirectory: URL? = nil,
        streamOutput: Bool
    ) throws -> Output {
        try run(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: [tool] + arguments,
            currentDirectory: currentDirectory,
            streamOutput: streamOutput
        )
    }
}
