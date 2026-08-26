/// `while`, `repeat`-`while`, and `for`-`in` with a `where` clause.
public struct Loops {
    public init() {}

    /// swift-coverage requires the loop body to run at least once; it does
    /// not separately require a zero-iteration execution (the loop
    /// condition being false the very first time it's checked) — see
    /// `SEMANTICS.md`. This function is always called with `n > 0` in
    /// tests, so the "ran zero times" path is genuinely never exercised,
    /// and genuinely never flagged either.
    public func countDown(_ n: Int) -> Int {
        var count = n
        while count > 0 {
            count -= 1
        }
        return count
    }

    /// `repeat`-`while` always runs its body at least once by construction
    /// — there is no "zero iterations" outcome possible for it to begin
    /// with, unlike `while`.
    public func repeatUntilZero(_ n: Int) -> Int {
        var count = n
        repeat {
            count -= 1
        } while count > 0
        return count
    }

    /// `for`-`in` with a `where` clause. The `where` filters which elements
    /// reach the body; swift-coverage still creates just one obligation for
    /// the loop body as a whole (was it entered at all), the same as a
    /// plain `for`-`in` — it does not separately require the filter to have
    /// both included and excluded at least one element.
    public func sumEvenNumbers(_ numbers: [Int]) -> Int {
        var total = 0
        for number in numbers where number % 2 == 0 {
            total += number
        }
        return total
    }
}
