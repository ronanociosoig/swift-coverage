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
/// `xcrun llvm-cov export` against it and every binary that could carry
/// coverage-instrumented code — the exact same region-level JSON `swift
/// test`'s own coverage export uses, so every downstream matching/reporting
/// path stays identical.
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

    // MARK: - Locating profdata + binaries, exporting JSON

    private func exportCoverageJSON() throws -> String {
        let profdata = try findNewestFile(matching: "Coverage.profdata", under: "Build/ProfileData")
        var binaries = try findCoverageBinaries()

        // `llvm-cov export` takes one positional binary and any further
        // ones via repeated `-object`; passing only the test bundle (as an
        // earlier version of this did) silently drops coverage for an
        // app-hosted test target's app executable, or for any dynamic
        // framework — the counts for that code exist in the profdata, they
        // just never get matched to source without their own binary here.
        //
        // Not every discovered binary necessarily carries coverage mapping,
        // though: alongside real ones, Xcode also embeds binaries with none
        // at all (a UI test runner's own host binary is typically one) and
        // `llvm-cov` fails its *entire* run over a single one of those,
        // rather than skipping it. Its error names the offending binary, so
        // on failure this drops that one binary and retries instead of
        // giving up outright.
        while true {
            var arguments = ["llvm-cov", "export", "-format=text", "-instr-profile=\(profdata)"]
            arguments.append(binaries[0])
            for binary in binaries.dropFirst() {
                arguments += ["-object", binary]
            }

            let export = try ProcessRunner.run(tool: "xcrun", arguments: arguments, streamOutput: false)
            if export.exitCode == 0, !export.stdout.isEmpty {
                let outputURL = URL(fileURLWithPath: derivedDataPath).appendingPathComponent(
                    "swift-coverage-export.json")
                try export.stdout.write(to: outputURL, atomically: true, encoding: .utf8)
                return outputURL.path
            }

            guard let culprit = binaries.first(where: { export.stderr.contains($0) }), binaries.count > 1 else {
                throw SwiftCoverageError.coverageDataUnavailable
            }
            binaries.removeAll { $0 == culprit }
        }
    }

    /// Apple's own testing-support frameworks, auto-embedded into every
    /// `.xctest`/UI-test-runner bundle regardless of what the project itself
    /// uses. Never coverage-instrumented, so never worth passing to
    /// `llvm-cov` — see `findCoverageBinaries`.
    private static let appleTestingFrameworkNames: Set<String> = [
        "XCTest", "XCTestCore", "XCTestSupport", "XCUnit",
        "XCUIAutomation", "XCTAutomationSupport", "Testing",
    ]

    /// Finds every binary under the most-recently-built
    /// `Build/Products/<Configuration>-<sdk>` directory that could carry
    /// coverage-instrumented code:
    ///
    /// - The scheme's own `.xctest` bundle, plus any `.app` executable and
    ///   `.framework` it embeds or links against. A test bundle alone only
    ///   covers code statically linked into *it*; an app-hosted test target
    ///   (code under test running inside the app executable, not the test
    ///   bundle) or a project with dynamic frameworks needs those binaries
    ///   passed to `llvm-cov` too, or coverage for anything outside the
    ///   first binary it's given goes unreported.
    /// - Loose `.o` files sitting directly in the products directory: when a
    ///   local Swift package's library target is consumed by a native Xcode
    ///   target (as opposed to a plain `swift test` build), Xcode's build
    ///   system can compile it straight to an object file there rather than
    ///   wrapping it in a `.framework`/`.xctest` — `llvm-cov` reads a raw
    ///   `.o`'s coverage mapping just as well as a linked binary's.
    private func findCoverageBinaries() throws -> [String] {
        guard let productsDir = newestProductsDirectory() else {
            throw SwiftCoverageError.coverageDataUnavailable
        }
        guard let enumerator = FileManager.default.enumerator(at: productsDir, includingPropertiesForKeys: nil)
        else {
            throw SwiftCoverageError.coverageDataUnavailable
        }

        // An app-hosted test target's `.xctest` bundle lives *inside* the
        // app bundle (`Name.app/PlugIns/NameTests.xctest`), and a framework
        // can itself embed nested frameworks — so descending stops only at
        // `.framework`/`.xctest` themselves, never at `.app`, or nested
        // bundles like this are silently never found. Loose `.o` files are
        // only collected at the top level: `-object`-worthy ones live
        // directly in the products directory, not buried in intermediates.
        var bundles: [URL] = []
        var looseObjectFiles: [URL] = []
        for case let url as URL in enumerator {
            if ["app", "framework", "xctest"].contains(url.pathExtension) {
                bundles.append(url)
                if url.pathExtension != "app" {
                    enumerator.skipDescendants()
                }
            } else if url.pathExtension == "o", url.deletingLastPathComponent().path == productsDir.path {
                looseObjectFiles.append(url)
            }
        }

        // Xcode embeds Apple's own testing-support frameworks (XCTest,
        // Testing, XCUIAutomation, ...) into every `.xctest`/UI-test-runner
        // bundle it builds. They carry no coverage mapping at all — handing
        // one to `llvm-cov export -object` doesn't just contribute nothing,
        // it fails the whole command ("could not load coverage
        // information"), taking every other binary's data down with it.
        // (A UI-test-runner's own host binary hits the identical failure
        // and isn't caught by this name-based filter; `exportCoverageJSON`'s
        // retry loop is the general-purpose backstop for that case, and any
        // other binary that turns out to have no mapping at all.)
        let entries = bundles.compactMap { bundle -> (name: String, binary: String)? in
            let name = bundle.deletingPathExtension().lastPathComponent
            guard !Self.appleTestingFrameworkNames.contains(name) else { return nil }
            guard let binary = mainBinary(in: bundle) else { return nil }
            return (name, binary)
        }
        guard !entries.isEmpty || !looseObjectFiles.isEmpty else {
            throw SwiftCoverageError.coverageDataUnavailable
        }

        // llvm-cov's first positional binary anchors its source-file
        // discovery; the scheme's own test bundle is guaranteed to exist,
        // so it goes first, with every other instrumented binary following
        // as `-object`.
        var binaries = entries.map(\.binary)
        if let schemeIndex = entries.firstIndex(where: { $0.name == scheme }) {
            binaries.swapAt(0, schemeIndex)
        }
        binaries.append(contentsOf: looseObjectFiles.map(\.path))
        return binaries
    }

    /// Returns a bundle's actual Mach-O binary — the file `llvm-cov` needs,
    /// not the bundle directory itself. Handles both the flat iOS/simulator
    /// bundle layout (`Name.xctest/Name`) and the macOS bundle layout
    /// (`Name.xctest/Contents/MacOS/Name`).
    private func mainBinary(in bundle: URL) -> String? {
        let bundleName = bundle.deletingPathExtension().lastPathComponent
        let flat = bundle.appendingPathComponent(bundleName)
        if FileManager.default.fileExists(atPath: flat.path) {
            return flat.path
        }
        let macOSStyle = bundle.appendingPathComponent("Contents/MacOS/\(bundleName)")
        if FileManager.default.fileExists(atPath: macOSStyle.path) {
            return macOSStyle.path
        }
        return nil
    }

    /// The most-recently-modified immediate subdirectory of `Build/Products`
    /// (e.g. `Debug-iphonesimulator`) — scoping binary discovery to it keeps
    /// a stale build configuration from a previous run out of this one's set.
    private func newestProductsDirectory() -> URL? {
        let productsDir = URL(fileURLWithPath: derivedDataPath).appendingPathComponent("Build/Products")
        guard
            let entries = try? FileManager.default.contentsOfDirectory(
                at: productsDir, includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles])
        else {
            return nil
        }
        return entries.max(by: { modificationDate($0) < modificationDate($1) })
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
