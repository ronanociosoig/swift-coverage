import Foundation

public enum SwiftCoverageError: LocalizedError {
    case packageNotFound(path: String)
    case testsFailed
    case coverageDataUnavailable
    case coverageDecodeFailed(underlying: Error)
    case usage(String)

    public var errorDescription: String? {
        switch self {
        case .packageNotFound(let path):
            return "No Package.swift found at \(path)."
        case .testsFailed:
            return "Tests failed (or the build failed) before coverage could be checked."
        case .coverageDataUnavailable:
            return "No coverage data was produced. Did --enable-code-coverage take effect, and did any tests run?"
        case .coverageDecodeFailed(let underlying):
            return "Failed to decode coverage export JSON: \(underlying.localizedDescription)"
        case .usage(let message):
            return message
        }
    }
}
