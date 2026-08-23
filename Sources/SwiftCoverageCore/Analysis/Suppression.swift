import Foundation
import SwiftSyntax

/// The three `// swift-coverage:ignore*` directives recognized in source
/// comments. Each is matched as an exact, trimmed `//` line comment (never
/// `///`, so documentation is never mistaken for a directive) — there is no
/// prefix matching, so `ignore` and `ignore-branch` can never be confused.
enum SuppressionMarker: String {
    /// Directly above a function/initializer/deinitializer/computed-property
    /// declaration: excludes that whole declaration from analysis.
    case ignore = "swift-coverage:ignore"
    /// Directly above a branch-introducing keyword (`if`, `else`, `guard`,
    /// `case`, `catch`, `for`, `while`, `repeat`), or above the statement
    /// containing a ternary/`??`: excludes just that one branch.
    case ignoreBranch = "swift-coverage:ignore-branch"
    /// In the leading trivia of a file's first token: excludes the whole file.
    case ignoreFile = "swift-coverage:ignore-file"
}

/// Parses `// swift-coverage:ignore*` annotations out of `Trivia`.
enum Suppression {
    static func containsIgnore(_ trivia: Trivia) -> Bool {
        contains(.ignore, in: trivia)
    }

    static func containsIgnoreBranch(_ trivia: Trivia) -> Bool {
        contains(.ignoreBranch, in: trivia)
    }

    static func fileIsIgnored(_ sourceFile: SourceFileSyntax) -> Bool {
        guard let firstToken = sourceFile.firstToken(viewMode: .sourceAccurate) else { return false }
        return contains(.ignoreFile, in: firstToken.leadingTrivia)
    }

    private static func contains(_ marker: SuppressionMarker, in trivia: Trivia) -> Bool {
        for piece in trivia {
            guard case .lineComment(let text) = piece, text.hasPrefix("//") else { continue }
            let content = text.dropFirst(2).trimmingCharacters(in: .whitespaces)
            if content == marker.rawValue { return true }
        }
        return false
    }
}
