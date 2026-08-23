/// A 1-based line/column position, matching both SwiftSyntax's
/// `SourceLocationConverter` and llvm-cov's `export` JSON coordinates, so
/// spans computed from parsed source can be compared directly against
/// coverage regions decoded from a profile.
public struct SourcePosition: Comparable, Hashable, Sendable {
    public var line: Int
    public var column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }

    public static func < (lhs: SourcePosition, rhs: SourcePosition) -> Bool {
        (lhs.line, lhs.column) < (rhs.line, rhs.column)
    }
}

/// A half-open source range `[start, end)` within one file.
public struct SourceSpan: Hashable, Sendable {
    public var start: SourcePosition
    public var end: SourcePosition

    public init(start: SourcePosition, end: SourcePosition) {
        self.start = start
        self.end = end
    }

    public init(startLine: Int, startColumn: Int, endLine: Int, endColumn: Int) {
        self.init(
            start: SourcePosition(line: startLine, column: startColumn),
            end: SourcePosition(line: endLine, column: endColumn)
        )
    }

    /// Whether `other` lies entirely within this span.
    public func contains(_ other: SourceSpan) -> Bool {
        start <= other.start && other.end <= end
    }

    /// Whether `point` lies within `[start, end)`.
    public func contains(_ point: SourcePosition) -> Bool {
        start <= point && point < end
    }
}
