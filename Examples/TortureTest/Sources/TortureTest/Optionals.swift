/// `??`, optional chaining (`?.`), and the ternary operator (`?:`).
public struct Optionals {
    public init() {}

    /// A single `??`. swift-coverage requires only the fallback
    /// (right-hand side) to run; the left-hand-side-non-nil path is never
    /// separately required — see `SEMANTICS.md`. Deliberately called only
    /// with `nil` in tests (see `OptionalsTests`), so the fallback is
    /// covered and the non-nil path is never exercised at all — which,
    /// per that documented behavior, is *not* flagged as a gap.
    public func nameOrDefault(_ name: String?) -> String {
        name ?? "anonymous"
    }

    /// Chained `??` — each `??` is its own obligation (its own fallback
    /// region), independently matched. Exercises the first fallback but
    /// not the second (see `OptionalsTests`), which should surface as one
    /// covered and one uncovered obligation on the same line.
    public func firstNonNil(_ a: String?, _ b: String?) -> String {
        a ?? b ?? "neither"
    }

    /// Optional chaining (`?.`) is not itself a branch construct
    /// swift-coverage tracks — there is no `LogicBranch` for "was the
    /// optional nil at this `?.`". This function produces zero required
    /// branches on its own (see `SEMANTICS.md`); its `??` is the only
    /// obligation, fully exercised across both nil and non-nil `person`.
    public func streetName(_ person: Person?) -> String {
        person?.address?.street ?? "unknown"
    }

    /// The ternary operator: one obligation per side, independently
    /// matched, exactly like `if`/`else` (see `SEMANTICS.md`). Deliberately
    /// exercised on only the `then` side (see `OptionalsTests`), so the
    /// `else` side should surface as uncovered.
    public func sizeLabel(_ isLarge: Bool) -> String {
        isLarge ? "large" : "small"
    }
}

public struct Person {
    public var address: Address?
    public init(address: Address?) { self.address = address }
}

public struct Address {
    public var street: String
    public init(street: String) { self.street = street }
}
