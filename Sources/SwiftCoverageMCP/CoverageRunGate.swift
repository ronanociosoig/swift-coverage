import Foundation

/// Serializes `swift test` invocations across concurrent MCP tool calls.
///
/// The MCP server dispatches `tools/call` requests concurrently, but two
/// overlapping `swift test --enable-code-coverage` runs against the same
/// package would race on SwiftPM's shared `.build` state. `--skip-tests`
/// calls (which only read an already-written coverage export) don't go
/// through this gate and stay fully concurrent.
final class CoverageRunGate: @unchecked Sendable {
    static let shared = CoverageRunGate()
    private let lock = NSLock()
    private init() {}

    func run<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
}
