/// `#if`/`#elseif`/`#else`/`#endif` conditional compilation, and
/// `if #available`.
public struct ConditionalCompilation {
    public init() {}

    /// `#if`/`#else` selects which branch's *source code even exists* in a
    /// given build — there is no runtime "other path" to require coverage
    /// of, the way a normal `if` has. swift-coverage creates no branch
    /// obligation for `#if` itself, and never could: the clauses that
    /// didn't get compiled for this platform aren't present in the binary
    /// at all for a coverage region to describe.
    public func platformName() -> String {
        #if os(macOS)
            return "macOS"
        #elseif os(iOS)
            return "iOS"
        #else
            return "other"
        #endif
    }

    /// A normal `if` living inside an `#if`-selected block is still walked
    /// and detected exactly as if the `#if` weren't there — swift-coverage
    /// doesn't skip descending into conditional-compilation blocks, only
    /// declines to treat the `#if` itself as a branch. Fully exercised.
    public func describeCount(_ n: Int) -> String {
        #if os(macOS)
            if n > 1 {
                return "\(n) items"
            }
            return "\(n) item"
        #else
            return "\(n)"
        #endif
    }

    /// `if #available` is, syntactically, just another `IfExprSyntax`
    /// condition — detected exactly like any other `if`/`else`, one
    /// obligation per body. Deliberately checks a version above this
    /// package's own deployment target (`.macOS(.v13)`, see `Package.swift`)
    /// so there's a genuine runtime branch rather than one the compiler can
    /// prove statically true — and deliberately left with only the
    /// "modern" path exercised (see `ConditionalCompilationTests`), since
    /// the "legacy" path can only ever run on an OS this test suite isn't
    /// running on. That's a real, honest limitation worth having on record:
    /// some version-gated code genuinely can't have both sides exercised by
    /// one CI runner, and swift-coverage has no special-case for it — it
    /// reports the untested side as uncovered like any other.
    public func modernAPIDescription() -> String {
        if #available(macOS 14, *) {
            return "modern"
        } else {
            return "legacy"
        }
    }
}
