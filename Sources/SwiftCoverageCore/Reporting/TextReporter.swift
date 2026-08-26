import Foundation

/// Renders an `AnalysisReport` as human-readable text for a terminal or CI log.
public enum TextReporter {
    public static func render(_ report: AnalysisReport, verbose: Bool = false) -> String {
        var lines: [String] = []
        let covered = report.requiredBranchCount - report.uncoveredRequiredBranchCount

        if let diffBase = report.diffBase {
            lines.append(
                "swift-coverage: scoped to logic added/changed since '\(diffBase)' \u{2014} pre-existing gaps "
                    + "elsewhere are not included."
            )
        }
        lines.append(
            "swift-coverage: \(report.units.count) logic unit(s), \(report.requiredBranchCount) required branch(es)"
        )

        if let percent = report.lineCoveragePercent {
            let symbol = report.passes ? "\u{2714}" : "\u{2718}"
            let percentText = String(format: "%.1f", percent)
            lines.append("\(symbol) \(covered)/\(report.requiredBranchCount) required branches covered (\(percentText)%)")
        } else {
            lines.append("No required logic branches found \u{2014} nothing to check.")
        }

        let uncoveredUnits = report.unitsWithUncoveredLogic.sorted {
            ($0.filePath, $0.location.line) < ($1.filePath, $1.location.line)
        }
        if !uncoveredUnits.isEmpty {
            lines.append("")
            lines.append("Uncovered logic paths:")
            for unit in uncoveredUnits {
                let qualifiedName = unit.enclosingTypeName.map { "\($0).\(unit.name)" } ?? unit.name
                for branch in unit.uncoveredRequiredBranches {
                    let note = branch.evidence.map { "  [\($0.confidence.rawValue) confidence: \($0.detail)]" } ?? ""
                    lines.append(
                        "  \(unit.filePath):\(branch.span.start.line)  \(qualifiedName)  \(branch.label)\(note)"
                    )
                }
            }
            lines.append("")
            lines.append(
                "\(report.uncoveredRequiredBranchCount) uncovered logic path(s). Add a test that reaches each "
                    + "one, or annotate it with `// swift-coverage:ignore-branch` (or `// swift-coverage:ignore` "
                    + "for a whole declaration) if it's intentionally untested."
            )
        }

        if verbose, !report.filesWithoutLogic.isEmpty {
            lines.append("")
            lines.append("\(report.filesWithoutLogic.count) file(s) had no branching logic and were skipped:")
            for file in report.filesWithoutLogic {
                lines.append("  \(file)")
            }
        }

        return lines.joined(separator: "\n")
    }
}
