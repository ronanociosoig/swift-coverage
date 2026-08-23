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

    /// `true`/`false` once a covering region is found; `nil` when no coverage
    /// region falls within the branch's span at all — most often because
    /// `filePath` wasn't compiled into the target(s) under test, so there is
    /// simply no verdict to give.
    func isCovered(_ span: SourceSpan, in filePath: String) -> Bool? {
        guard let regions = regionsByFile[filePath] else { return nil }
        let candidates = regions.filter { $0.span.contains(span.start) }
        guard let entry = candidates.max(by: { $0.span.start < $1.span.start }) else { return nil }
        return entry.executionCount > 0
    }

    var isEmpty: Bool { regionsByFile.isEmpty }
}
