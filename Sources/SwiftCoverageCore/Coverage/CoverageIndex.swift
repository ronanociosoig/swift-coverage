/// Indexes coverage regions by absolute source-file path, and matches a
/// `LogicBranch`'s span against them.
///
/// Coverage regions nest (a function's region contains its `if`'s region,
/// which contains a nested `if`'s region, and so on), and a region's own
/// span doesn't always start exactly where the `LogicBranch` it corresponds
/// to starts: an `if`/`guard`/loop/`catch` body's region starts right where
/// that body does, but a `switch` case's region starts at the `case` label
/// itself, before its statements. So rather than requiring a region nested
/// inside the branch's span, "was this branch reached" is answered by
/// finding every region whose span *contains the branch's start position*,
/// and taking the one with the latest start — the innermost of them, i.e.
/// the region actually governing execution at that point.
///
/// This is necessarily heuristic — see `CoverageEvidence`, which makes that
/// explicit in the result rather than collapsing it into a bare `Bool`.
struct CoverageIndex {
    private var regionsByFile: [String: [CoverageRegion]]

    init(export: CoverageExport) {
        var byFile: [String: [CoverageRegion]] = [:]
        for datum in export.data {
            for function in datum.functions {
                guard let filename = function.filenames.first else { continue }
                let regions = function.regions.compactMap(CoverageRegion.init(raw:))
                byFile[filename, default: []].append(contentsOf: regions)
            }
        }
        for key in byFile.keys {
            byFile[key]?.sort { $0.span.start < $1.span.start }
        }
        self.regionsByFile = byFile
    }

    /// Matches `span` against the index and returns the full verdict: not
    /// just covered/uncovered, but which of the four evidence kinds
    /// produced that verdict (or the lack of one). See `CoverageEvidenceKind`.
    func evaluate(_ span: SourceSpan, in filePath: String) -> CoverageEvidence {
        guard let regions = regionsByFile[filePath] else {
            return CoverageEvidence(
                kind: .fileNotInstrumented,
                status: .unknown,
                confidence: .none,
                detail: "no coverage data for \(filePath) — it likely wasn't compiled into any tested target"
            )
        }

        let candidates = regions.filter { $0.span.contains(span.start) }
        guard let entry = candidates.max(by: { $0.span.start < $1.span.start }) else {
            return CoverageEvidence(
                kind: .noMatchingRegion,
                status: .unknown,
                confidence: .none,
                detail: "no coverage region contains \(Self.describe(span.start)) in \(filePath)"
            )
        }

        let status: CoverageStatus = entry.executionCount > 0 ? .covered : .uncovered
        let countPhrase = "executed \(entry.executionCount) time\(entry.executionCount == 1 ? "" : "s")"

        if entry.span == span {
            return CoverageEvidence(
                kind: .directExecution,
                status: status,
                confidence: .high,
                matchedRegionSpan: entry.span,
                executionCount: entry.executionCount,
                detail: "region \(Self.describe(entry.span)) matches this branch exactly, \(countPhrase)"
            )
        }
        return CoverageEvidence(
            kind: .inferredFromEnclosingRegion,
            status: status,
            confidence: .medium,
            matchedRegionSpan: entry.span,
            executionCount: entry.executionCount,
            detail:
                "inferred from enclosing region \(Self.describe(entry.span)) (branch span is \(Self.describe(span))), \(countPhrase)"
        )
    }

    var isEmpty: Bool { regionsByFile.isEmpty }

    private static func describe(_ position: SourcePosition) -> String {
        "\(position.line):\(position.column)"
    }

    private static func describe(_ span: SourceSpan) -> String {
        "[\(describe(span.start))–\(describe(span.end))]"
    }
}
