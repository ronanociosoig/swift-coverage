import Foundation

/// Runs `xcodebuild test` for a scheme and produces the same coverage
/// export JSON contract `CoverageRunner` produces from `swift test` — for
/// packages that can't be built by a bare `swift test` on macOS at all (an
/// iOS-only package, or any package only buildable through an Xcode
/// project/workspace).
///
/// `xcodebuild`'s own coverage reporting (`xcrun xccov view --report
/// --json`) is function-level only — coarser than the branch-level regions
/// this tool matches against. Instead, this runs with an explicit
/// `-derivedDataPath` so the raw `Coverage.profdata` xcodebuild writes
/// during the test run can be found deterministically afterward, then runs
/// `xcrun llvm-cov export` against it and the scheme's test binary — the
/// exact same region-level JSON `swift test`'s own coverage export uses, so
/// every downstream matching/reporting path stays identical.
public struct XcodeCoverageRunner {
    public var packagePath: String
    public var scheme: String
    public var destination: String
    public var project: String?
    public var workspace: String?
    public var derivedDataPath: String
    public var onlyTesting: [String]

    public init(
        packagePath: String,
        scheme: String,
        destination: String,
        project: String? = nil,
        workspace: String? = nil,
        derivedDataPath: String? = nil,
        onlyTesting: [String] = []
    ) {
        self.packagePath = packagePath
        self.scheme = scheme
        self.destination = destination
        self.project = project
        self.workspace = workspace
        self.derivedDataPath =
            derivedDataPath
            ?? URL(fileURLWithPath: packagePath).appendingPathComponent(".build/swift-coverage-xcode").path
        self.onlyTesting = onlyTesting
    }

    public struct Result {
        public var testsPassed: Bool
        public var coverageJSONPath: String?
    }

    public func run(streamOutput: Bool = true) throws -> Result {
        var arguments = [
            "test",
            "-scheme", scheme,
            "-destination", destination,
            "-derivedDataPath", derivedDataPath,
            "-enableCodeCoverage", "YES",
        ]
        if let project { arguments += ["-project", project] }
        if let workspace { arguments += ["-workspace", workspace] }
        for test in onlyTesting { arguments.append("-only-testing:\(test)") }

        let testRun = try ProcessRunner.run(
            tool: "xcodebuild",
            arguments: arguments,
            currentDirectory: URL(fileURLWithPath: packagePath),
            streamOutput: streamOutput
        )
        guard testRun.exitCode == 0 else {
            return Result(testsPassed: false, coverageJSONPath: nil)
        }

        let jsonPath = try? exportCoverageJSON()
        return Result(testsPassed: true, coverageJSONPath: jsonPath)
    }

    // MARK: - Locating profdata + the test binary, exporting JSON

    private func exportCoverageJSON() throws -> String {
        let profdata = try findNewestFile(matching: "Coverage.profdata", under: "Build/ProfileData")
        let binary = try findTestBinary()

        let export = try ProcessRunner.run(
            tool: "xcrun",
            arguments: ["llvm-cov", "export", "-format=text", "-instr-profile=\(profdata)", binary],
            streamOutput: false
        )
        guard export.exitCode == 0, !export.stdout.isEmpty else {
            throw SwiftCoverageError.coverageDataUnavailable
        }

        let outputURL = URL(fileURLWithPath: derivedDataPath).appendingPathComponent("swift-coverage-export.json")
        try export.stdout.write(to: outputURL, atomically: true, encoding: .utf8)
        return outputURL.path
    }

    /// Finds the scheme's `.xctest` bundle under `-derivedDataPath` and
    /// returns the path to its actual Mach-O binary — the file `llvm-cov`
    /// needs, not the bundle directory itself. Handles both the flat
    /// iOS/simulator bundle layout (`Name.xctest/Name`) and the macOS
    /// bundle layout (`Name.xctest/Contents/MacOS/Name`).
    private func findTestBinary() throws -> String {
        let productsDir = URL(fileURLWithPath: derivedDataPath).appendingPathComponent("Build/Products")
        guard
            let enumerator = FileManager.default.enumerator(
                at: productsDir, includingPropertiesForKeys: [.contentModificationDateKey])
        else {
            throw SwiftCoverageError.coverageDataUnavailable
        }

        var bundles: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "xctest" {
            bundles.append(url)
            enumerator.skipDescendants()
        }

        let preferred = bundles.first { $0.deletingPathExtension().lastPathComponent == scheme }
        guard let bundle = preferred ?? bundles.max(by: { modificationDate($0) < modificationDate($1) }) else {
            throw SwiftCoverageError.coverageDataUnavailable
        }

        let bundleName = bundle.deletingPathExtension().lastPathComponent
        let flatBinary = bundle.appendingPathComponent(bundleName)
        if FileManager.default.fileExists(atPath: flatBinary.path) {
            return flatBinary.path
        }
        let macOSBinary = bundle.appendingPathComponent("Contents/MacOS/\(bundleName)")
        if FileManager.default.fileExists(atPath: macOSBinary.path) {
            return macOSBinary.path
        }
        throw SwiftCoverageError.coverageDataUnavailable
    }

    /// Finds the most-recently-modified file named `name` among the
    /// immediate subdirectories of `relativePath` (there's normally exactly
    /// one, one per destination UDID `xcodebuild` has ever used against this
    /// `-derivedDataPath`; the newest is the one this run just wrote).
    private func findNewestFile(matching name: String, under relativePath: String) throws -> String {
        let dir = URL(fileURLWithPath: derivedDataPath).appendingPathComponent(relativePath)
        guard
            let entries = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey])
        else {
            throw SwiftCoverageError.coverageDataUnavailable
        }
        let matches = entries.map { $0.appendingPathComponent(name) }.filter {
            FileManager.default.fileExists(atPath: $0.path)
        }
        guard let newest = matches.max(by: { modificationDate($0) < modificationDate($1) }) else {
            throw SwiftCoverageError.coverageDataUnavailable
        }
        return newest.path
    }

    private func modificationDate(_ url: URL) -> Date {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.modificationDate] as? Date) ?? .distantPast
    }
}
