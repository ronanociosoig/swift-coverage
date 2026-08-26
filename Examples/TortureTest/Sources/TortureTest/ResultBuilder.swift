/// A minimal custom `@resultBuilder` — deliberately not SwiftUI's
/// `@ViewBuilder`, so this stays plain-macOS/Linux buildable, but the
/// compiler transformation it exercises (`if`/`else` bodies rewritten into
/// `buildEither(first:)`/`buildEither(second:)` calls, a bare `if` into
/// `buildOptional(_:)`) is the same mechanism `@ViewBuilder` uses. The
/// question this answers: does the *compiler's own* coverage-region
/// emission for a builder-transformed branch still land at the original
/// source position, the same as an ordinary `if`? See `SEMANTICS.md` for
/// the answer this fixture, once run through swift-coverage for real,
/// established.
@resultBuilder
public enum StringBuilder {
    public static func buildBlock(_ components: String...) -> String {
        components.joined()
    }

    public static func buildEither(first component: String) -> String {
        component
    }

    public static func buildEither(second component: String) -> String {
        component
    }

    public static func buildOptional(_ component: String?) -> String {
        component ?? ""
    }
}

public struct Greeter {
    public init() {}

    /// `if`/`else` here compiles to `buildEither(first:)`/
    /// `buildEither(second:)`; the bare `if` compiles to `buildOptional`.
    /// From swift-coverage's parse-time perspective these are ordinary
    /// `ifThen`/`ifElse` branches — the `@resultBuilder` attribute changes
    /// nothing about detection, only (potentially) about how faithfully the
    /// compiler's emitted coverage regions can be matched back to them.
    @StringBuilder
    public func greeting(name: String, isFormal: Bool, includeTime: Bool, time: String) -> String {
        if isFormal {
            "Good day, \(name)."
        } else {
            "Hey \(name)!"
        }
        if includeTime {
            " It's \(time)."
        }
    }
}
