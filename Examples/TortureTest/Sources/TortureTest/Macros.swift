/// `(value, "source text of value")` — Apple's canonical macro example.
/// Its own implementation is irrelevant here; what matters is that this
/// invocation syntax (`#stringify(...)`) sits inside a function with real
/// branches, so swift-coverage's behavior around it is directly observable.
@freestanding(expression)
public macro stringify<T>(_ value: T) -> (T, String) = #externalMacro(
    module: "TortureMacros", type: "StringifyMacro")

/// swift-coverage parses only the source text actually present in the file
/// — a macro's *expansion* (the code it generates at compile time) never
/// exists as text anywhere swift-coverage reads, so it's structurally
/// impossible for a branch inside a macro's generated implementation to
/// become an obligation. What IS visible is the macro invocation's own
/// argument list, exactly as written.
///
/// This function's `if` is entirely unrelated to the macro syntactically —
/// `#stringify(n)` is just an expression used inside the branch body — and
/// is detected identically to any other `if`. That's the whole point: a
/// macro invocation is syntactically inert as far as branch detection is
/// concerned; it neither hides nor duplicates the branches around it.
public struct MacroUsage {
    public init() {}

    public func describe(_ n: Int) -> String {
        if n > 0 {
            let (value, source) = #stringify(n)
            return "\(source) = \(value), positive"
        }
        return "non-positive"
    }
}
