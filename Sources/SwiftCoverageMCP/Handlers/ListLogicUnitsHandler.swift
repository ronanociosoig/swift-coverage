import Foundation
import MCP
import SwiftCoverageCore

/// Handles the `list_logic_units` tool: parses source only (no test run) and
/// lists every logic unit and its branches.
enum ListLogicUnitsHandler {
    struct BranchDTO: Codable {
        var kind: String
        var label: String
        var line: Int
        var suppressed: Bool
    }

    struct UnitDTO: Codable {
        var name: String
        var signature: String
        var type: String?
        var file: String
        var line: Int
        var complexity: Int
        var suppressed: Bool
        var branches: [BranchDTO]
    }

    struct ResultDTO: Codable {
        var units: [UnitDTO]
        var filesWithoutLogic: [String]
    }

    static func handle(_ arguments: [String: Value]?) async -> CallTool.Result {
        guard let path = ParamExtractor.string("path", from: arguments) else {
            return .text("Error: 'path' parameter is required", isError: true)
        }
        let include = ParamExtractor.stringArray("include", from: arguments) ?? []
        let exclude = ParamExtractor.stringArray("exclude", from: arguments) ?? []

        let analyzer = SwiftCoverageAnalyzer(packagePath: path, include: include, exclude: exclude)
        do {
            let (units, filesWithoutLogic) = try analyzer.collectLogicUnits()
            let dto = ResultDTO(
                units: units.map { unit in
                    UnitDTO(
                        name: unit.name,
                        signature: unit.signature,
                        type: unit.enclosingTypeName,
                        file: unit.filePath,
                        line: unit.location.line,
                        complexity: unit.cyclomaticComplexity,
                        suppressed: unit.isSuppressed,
                        branches: unit.branches.map { branch in
                            BranchDTO(
                                kind: branch.kind.rawValue,
                                label: branch.label,
                                line: branch.span.start.line,
                                suppressed: branch.isSuppressed
                            )
                        }
                    )
                },
                filesWithoutLogic: filesWithoutLogic
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(dto)
            return .text(String(data: data, encoding: .utf8) ?? "{}", isError: false)
        } catch {
            return .text("Error: \(error.localizedDescription)", isError: true)
        }
    }
}
