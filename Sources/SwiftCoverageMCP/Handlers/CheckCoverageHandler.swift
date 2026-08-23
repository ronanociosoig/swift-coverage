import MCP
import SwiftCoverageCore

/// Handles the `check_coverage` tool: runs (or reuses) coverage data and
/// returns the full report.
enum CheckCoverageHandler {
    static func handle(_ arguments: [String: Value]?) async -> CallTool.Result {
        guard let args = CoverageRequest.parse(arguments) else {
            return .text("Error: 'path' parameter is required", isError: true)
        }
        let format = ParamExtractor.string("format", from: arguments) ?? "json"

        do {
            let report = try CoverageRequest.buildReport(args)
            let output = format == "text" ? TextReporter.render(report) : try JSONReporter.render(report)
            // isError reflects a tool-call failure, not a failed coverage
            // check: `passes: false` in the returned report is a normal,
            // useful result the caller acts on, not an MCP error.
            return .text(output, isError: false)
        } catch let error as SwiftCoverageError {
            return .text(error.errorDescription ?? "Unknown error", isError: true)
        } catch {
            return .text("Error: \(error.localizedDescription)", isError: true)
        }
    }
}
