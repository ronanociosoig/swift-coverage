import Foundation
import MCP
import SwiftCoverageCore

/// Handles the `list_uncovered_branches` tool: the same analysis as
/// `check_coverage`, reduced to just the branches that still need a test.
enum ListUncoveredBranchesHandler {
    struct BranchDTO: Codable {
        var file: String
        var line: Int
        var unit: String
        var branch: String
        var reason: String
    }

    struct ResultDTO: Codable {
        var passes: Bool
        var uncoveredCount: Int
        var branches: [BranchDTO]
    }

    static func handle(_ arguments: [String: Value]?) async -> CallTool.Result {
        guard let args = CoverageRequest.parse(arguments) else {
            return .text("Error: 'path' parameter is required", isError: true)
        }

        do {
            let report = try CoverageRequest.buildReport(args)
            let branches = report.unitsWithUncoveredLogic.flatMap { unit -> [BranchDTO] in
                let qualifiedName = unit.enclosingTypeName.map { "\($0).\(unit.name)" } ?? unit.name
                return unit.uncoveredRequiredBranches.map { branch in
                    BranchDTO(
                        file: unit.filePath,
                        line: branch.span.start.line,
                        unit: qualifiedName,
                        branch: branch.label,
                        reason: branch.isCovered == nil
                            ? "no coverage data for this file" : "never reached by a test"
                    )
                }
            }
            let dto = ResultDTO(passes: report.passes, uncoveredCount: branches.count, branches: branches)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(dto)
            return .text(String(data: data, encoding: .utf8) ?? "{}", isError: false)
        } catch let error as SwiftCoverageError {
            return .text(error.errorDescription ?? "Unknown error", isError: true)
        } catch {
            return .text("Error: \(error.localizedDescription)", isError: true)
        }
    }
}
