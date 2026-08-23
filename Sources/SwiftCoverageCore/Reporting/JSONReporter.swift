import Foundation

/// Renders an `AnalysisReport` as machine-readable JSON — the format meant
/// for a coding agent or CI step to parse, rather than a human to read.
public enum JSONReporter {
    struct BranchDTO: Codable {
        var kind: String
        var label: String
        var line: Int
        var column: Int
        var covered: Bool?
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

    struct ReportDTO: Codable {
        var packagePath: String
        var passes: Bool
        var requiredBranchCount: Int
        var uncoveredRequiredBranchCount: Int
        var lineCoveragePercent: Double?
        var units: [UnitDTO]
        var filesWithoutLogic: [String]
    }

    public static func render(_ report: AnalysisReport) throws -> String {
        let dto = ReportDTO(
            packagePath: report.packagePath,
            passes: report.passes,
            requiredBranchCount: report.requiredBranchCount,
            uncoveredRequiredBranchCount: report.uncoveredRequiredBranchCount,
            lineCoveragePercent: report.lineCoveragePercent,
            units: report.units.map(unitDTO),
            filesWithoutLogic: report.filesWithoutLogic
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(dto)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func unitDTO(_ unit: LogicUnit) -> UnitDTO {
        UnitDTO(
            name: unit.name,
            signature: unit.signature,
            type: unit.enclosingTypeName,
            file: unit.filePath,
            line: unit.location.line,
            complexity: unit.cyclomaticComplexity,
            suppressed: unit.isSuppressed,
            branches: unit.branches.map(branchDTO)
        )
    }

    private static func branchDTO(_ branch: LogicBranch) -> BranchDTO {
        BranchDTO(
            kind: branch.kind.rawValue,
            label: branch.label,
            line: branch.span.start.line,
            column: branch.span.start.column,
            covered: branch.isCovered,
            suppressed: branch.isSuppressed
        )
    }
}
