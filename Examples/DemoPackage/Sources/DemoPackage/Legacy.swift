/// A defensive branch that genuinely can't be reached from a test without
/// contortion. Annotated so swift-coverage doesn't demand a test for it.
public struct Legacy {
    public init() {}

    public func normalize(_ value: Int) -> Int {
        // swift-coverage:ignore-branch
        guard value >= 0 else {
            preconditionFailure("negative values should be unreachable by construction")
        }
        return value
    }
}
