public enum TortureError: Error {
    case validation(String)
    case network
}

/// `do`/`try`/`catch` with multiple typed/pattern catch clauses, and
/// `defer`.
public struct ErrorHandling {
    public init() {}

    /// Two typed catch clauses plus a catch-all. Each is its own branch
    /// obligation, matched independently — deliberately left with only the
    /// `.validation` clause and the success path exercised (see
    /// `ErrorHandlingTests`); `.network` and the catch-all are left
    /// uncovered on purpose.
    public func run(_ perform: () throws -> Int) -> String {
        do {
            let value = try perform()
            return "ok: \(value)"
        } catch TortureError.validation(let message) {
            return "validation failed: \(message)"
        } catch TortureError.network {
            return "network failed"
        } catch {
            return "unknown: \(error)"
        }
    }

    /// `defer` is unconditional — it always runs once its scope is
    /// entered, regardless of which path leaves that scope. swift-coverage
    /// creates no branch obligation for a `defer` block at all: there is
    /// exactly one outcome ("ran"), not an alternative to require coverage
    /// of. The `if`/`else` here are the only two obligations this function
    /// produces; both exercised.
    public func withCleanup(_ shouldFail: Bool) -> String {
        var log: [String] = []
        defer { log.append("cleanup") }

        if shouldFail {
            log.append("failed")
        } else {
            log.append("succeeded")
        }
        return log.joined(separator: ",")
    }
}
