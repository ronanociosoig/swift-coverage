import Foundation

public enum SwiftCoverageError: LocalizedError {
    case packageNotFound(path: String)
    case testsFailed
    case coverageDataUnavailable
    case coverageDecodeFailed(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .packageNotFound(let path):
            return "No Package.swift found at \(path)."
        case .testsFailed:
            return "swift test failed; fix failing tests before checking coverage."
        case .coverageDataUnavailable:
            return "No coverage data was produced. Did --enable-code-coverage take effect, and did any tests run?"
        case .coverageDecodeFailed(let underlying):
            return "Failed to decode coverage export JSON: \(underlying.localizedDescription)"
        }
    }
}
