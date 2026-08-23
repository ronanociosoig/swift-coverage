/// Minimal decode of the JSON emitted by `swift test --show-codecov-path`
/// (SwiftPM writes this via `llvm-cov export -format=text` under the hood).
/// Only what `swift-coverage` needs — per-function source regions — is
/// modeled; `files`, `segments`, and `summary` in the real export are ignored.
struct CoverageExport: Decodable {
    var data: [CoverageExportDatum]
}

struct CoverageExportDatum: Decodable {
    var functions: [CoverageFunctionRecord]
}

struct CoverageFunctionRecord: Decodable {
    var name: String
    var regions: [[Int]]
    var filenames: [String]
}

/// A region's kind, encoded at index 7 of its raw array. Only `.code`
/// regions are used for branch matching — expansion/skipped/gap regions
/// don't mean "this specific branch body ran".
enum CoverageRegionKind: Int {
    case code = 0
    case expansion = 1
    case skipped = 2
    case gap = 3
    case branch = 4
}

/// One decoded, file-relative code region: a span plus how many times it executed.
struct CoverageRegion {
    var span: SourceSpan
    var executionCount: Int

    /// Decodes a raw llvm-cov region array (`[lineStart, colStart, lineEnd,
    /// colEnd, executionCount, fileID, expandedFileID, kind, ...]`). Returns
    /// `nil` for anything that isn't a plain, same-file `.code` region.
    init?(raw: [Int]) {
        guard raw.count >= 8 else { return nil }
        let fileID = raw[5]
        let expandedFileID = raw[6]
        guard fileID == 0, expandedFileID == 0 else { return nil }
        guard CoverageRegionKind(rawValue: raw[7]) == .code else { return nil }
        span = SourceSpan(startLine: raw[0], startColumn: raw[1], endLine: raw[2], endColumn: raw[3])
        executionCount = raw[4]
    }
}
