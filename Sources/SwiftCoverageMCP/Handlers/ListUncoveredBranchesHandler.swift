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
        /// "covered" | "uncovered" | "unknown" — always non-"covered" here,
        /// since this list is only the ones that still need attention, but
        /// distinguishes a confirmed miss from no verdict being reachable.
        var status: String
        /// "high" | "medium" | "none" — how much to trust `status`.
        var confidence: String
        /// "direct_execution" | "inferred_from_enclosing_region" |
        /// "no_matching_region" | "file_not_instrumented".
        var evidence: String
        var detail: String
        /// A concrete next step, e.g. "Add a test calling Discount.tierName
        /// with a value matching `case .vip`."
        var suggestion: String
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
                    let evidence = branch.evidence
                    return BranchDTO(
                        file: unit.filePath,
                        line: branch.span.start.line,
                        unit: qualifiedName,
                        branch: branch.label,
                        status: evidence?.status.rawValue ?? CoverageStatus.unknown.rawValue,
                        confidence: evidence?.confidence.rawValue ?? CoverageConfidence.none.rawValue,
                        evidence: evidence?.kind.rawValue ?? "not_evaluated",
                        detail: evidence?.detail ?? "no coverage data for this branch",
                        suggestion: SuggestionGenerator.suggest(for: branch, in: unit)
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
