import Foundation

/// Finds Swift source files to analyze for logic units. Defaults to
/// everything under `Sources/` (falling back to the package root if there is
/// no `Sources/` directory), skipping `.build` and `Tests`; `--include` /
/// `--exclude` glob patterns, matched against the path relative to the
/// package root, narrow that further.
enum FileDiscovery {
    static func sourceFiles(
        packagePath: String,
        include: [String],
        exclude: [String]
    ) throws -> [String] {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: packagePath).standardizedFileURL
        let sourcesRoot = root.appendingPathComponent("Sources")
        let searchRoot = fm.fileExists(atPath: sourcesRoot.path) ? sourcesRoot : root

        guard
            let enumerator = fm.enumerator(
                at: searchRoot,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        let excludeMatchers = exclude.map(GlobMatcher.init)
        let includeMatchers = include.map(GlobMatcher.init)

        var results: [String] = []
        for case let url as URL in enumerator {
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDirectory {
                if url.lastPathComponent == ".build" || url.lastPathComponent == "Tests" {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard url.pathExtension == "swift" else { continue }

            let relativePath =
                url.path.hasPrefix(root.path) ? String(url.path.dropFirst(root.path.count + 1)) : url.path
            if excludeMatchers.contains(where: { $0.matches(relativePath) }) { continue }
            if !includeMatchers.isEmpty, !includeMatchers.contains(where: { $0.matches(relativePath) }) { continue }
            results.append(url.path)
        }
        return results.sorted()
    }
}

/// A small `*` / `**` glob matcher — enough for `--include`/`--exclude` path
/// filters without pulling in a full glob library. `*` matches within one
/// path component, `**` matches across components.
struct GlobMatcher {
    private let regex: NSRegularExpression?

    init(pattern: String) {
        let escaped = NSRegularExpression.escapedPattern(for: pattern)
        let withDoubleStar = escaped.replacingOccurrences(of: "\\*\\*", with: "\u{0}")
        let withSingleStar = withDoubleStar.replacingOccurrences(of: "\\*", with: "[^/]*")
        let final = withSingleStar.replacingOccurrences(of: "\u{0}", with: ".*")
        regex = try? NSRegularExpression(pattern: "^\(final)$")
    }

    func matches(_ path: String) -> Bool {
        guard let regex else { return false }
        let range = NSRange(path.startIndex..., in: path)
        return regex.firstMatch(in: path, range: range) != nil
    }
}
