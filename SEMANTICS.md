# swift-coverage: semantic specification

This document states, construct by construct, exactly what swift-coverage requires and does not
require. It is not aspirational — every claim below is backed by a fixture in
[`Examples/TortureTest`](Examples/TortureTest), a real, compiled, tested SwiftPM package (including
a real macro compiler plugin and a custom result builder), and every fixture's *predicted* coverage
outcome was checked against `swift-coverage`'s *actual* output before this document was written. Run
it yourself:

```sh
cd Examples/TortureTest && swift test
swift-coverage Examples/TortureTest --verbose
```

As of the run this document was written from: **22 logic units, 36 required branches, 28 covered
(77.8%)**, with exactly the 8 gaps predicted below (plus one genuine surprise, §10) — and one
prediction that was initially *wrong* in an instructive way: see §1.

## The core model

swift-coverage requires every **explicit alternative code path** written in your source to be
reached by a test. It does not implement classical two-outcome branch coverage (both true and false
of every condition) — see §1 and §9 for exactly where those differ. A construct with no explicit
alternative (a bare `if` with no `else`, a stored property) produces no obligation at all: there is
nothing to leave uncovered, because nothing was required.

Each numbered section below is: what's detected, what obligation(s) it produces, and what — if
anything — is *not* required despite intuitively seeming like it should be.

## Confidence and evidence: making the heuristic visible

Matching a branch's source span against a coverage export is inherently heuristic (see
`CoverageIndex`'s own doc comment for the mechanism), and swift-coverage does not hide that behind a
bare `true`/`false`. Every branch's verdict carries a `CoverageEvidence`: a `status`
(`covered`/`uncovered`/`unknown`), a `confidence` (`high`/`medium`/`none`) derived mechanically from
*how* that status was reached, an `evidence` kind, and a human-readable `detail`. In JSON
(`check_coverage`, `--format json`, `list_uncovered_branches`):

```json
{ "kind": "case", "branch": "case .vip", "line": 40, "column": 13,
  "status": "uncovered", "confidence": "high", "evidence": "direct_execution",
  "detail": "region [40:13–42:6] matches this branch exactly, executed 0 times",
  "suppressed": false }
```

Four evidence kinds, in decreasing order of how much to trust the verdict:

| Evidence kind | Confidence | Meaning |
|---|---|---|
| `direct_execution` | `high` | The matched coverage region's span **exactly equals** the branch's own span — this region unambiguously *is* the branch, not a proxy standing in for it. |
| `inferred_from_enclosing_region` | `medium` | A region was matched (the innermost one whose span contains the branch's start), but its span differs from the branch's own — the verdict is inferred from an enclosing/overlapping region rather than read off an exact match. |
| `no_matching_region` | `none` | The branch's file has coverage data (it was instrumented), but no region's span contains the branch's start position at all. `status` is `unknown`, not `uncovered` — no verdict was reachable, which is a different claim from a confirmed miss. |
| `file_not_instrumented` | `none` | The branch's file has no coverage data in the export whatsoever — most often because it wasn't compiled into any tested target. `status` is `unknown` for the same reason as above. |

**`unknown` still counts as a failure** for `swift-coverage check`'s pass/fail gate, same as
`uncovered` — "no evidence this ran" is exactly the kind of gap a percentage threshold can hide, so
it isn't a silent pass. What changes is that the *reason* is now visible and distinguishable: a
`file_not_instrumented` branch needs "make sure this file is compiled into a tested target," not
"write a test for this specific line," and conflating the two used to make that fix harder to find.

**Which construct lands on which confidence is not asserted — it was measured**, across every
fixture in this document, by running `swift-coverage Examples/TortureTest --format json` and
tabulating `evidence` per `kind`:

| Branch kind | Evidence kind observed | Confidence |
|---|---|---|
| `if`, `else`, `guard-else`, `catch`, `for`, `while`, `repeat-while` | `direct_execution` | `high` |
| `??` (`nil-coalescing`), ternary `then`/`else` | `direct_execution` | `high` |
| `switch` `case` (including `default`) | `inferred_from_enclosing_region`, always | `medium` |

Only `switch` cases come out `medium` — every other tracked construct's computed span happens to
match the compiler's own region exactly, which was not obvious in advance (§4 explains why `switch`
is the exception: its region starts at the `case` label, before the branch's own statements).

---

## 1. Compound boolean conditions (`&&`, `||`)

**Fixture:** `CompoundConditions.swift`

```swift
if a && b { "both" } else { "not both" }
if a || b { "at least one" } else { "neither" }
```

**Required:** one `if-then` obligation, one `if-else` obligation — for the condition **as a whole**,
regardless of how many `&&`/`||` operands it contains.

**Not required:** independent coverage of each operand's outcome. `if a && b` has four semantically
distinct paths (`a` false and `b` never evaluated; `a` true, `b` false; both true — short-circuit
means `a` false, `b` true is unreachable) but exactly one pass/fail signal in swift-coverage's model.
A test suite that always calls this with `a == true` and only ever varies `b` will satisfy both
obligations without `a` ever having been tested false. This is the single largest gap between
"every explicit alternative code path" and true branch coverage — see §9.

**Verified:** `requiresEitherTrue` was deliberately tested with only the "true" outcome exercised;
swift-coverage correctly flagged the `else` body as uncovered, and nothing about the `&&`/`||`
structure itself was separately flagged (because nothing tracks it).

**A process note, left in deliberately:** this fixture's first draft wrote `requiresBothTrue` as a
bare `if a && b { return "both" }` followed by an unconditional `return "not both"` — not an actual
`if`/`else`. Per §7's "no obligation without a written alternative" rule, that produced only *one*
obligation, not two, so the "both obligations covered" claim this section makes was false until the
fixture was rewritten with a real `else`. The regression test in
`Tests/SwiftCoverageCoreTests/TortureFixtureDetectionTests.swift` caught this immediately (asserting
`[.ifThen, .ifElse]` against a fixture that only produced `[.ifThen]`) — which is itself the best
demonstration in this document of why the fixtures are checked against actual tool output rather
than trusted on inspection.

---

## 2. `if case`

**Fixture:** `PatternMatching.swift` — `isCircle`

```swift
if case .circle = shape { return true }
return false
```

**Required:** treated exactly like a plain `if`/implicit-fallthrough — one `if-then` obligation for
the pattern-match body. (There's no `else` here, so per §7 there's no second obligation either.)
Pattern matching itself isn't specially modeled; `if case` is syntactically just another `IfExprSyntax`
to the collector.

**Verified:** fully exercised (both `.circle` and non-`.circle` inputs tested), zero surprises.

---

## 3. `guard case let`

**Fixture:** `PatternMatching.swift` — `circleRadius`

```swift
guard case .circle(let radius) = shape else { return nil }
return radius
```

**Required:** one obligation — the `else` body. Exactly like a plain `guard`, binding an associated
value changes nothing about what's required.

**Not required:** the guard's success path (falling through to `return radius`) has no obligation
of its own — see §7, this is the general guard-success-path gap, not something specific to `case let`.

**Verified:** deliberately tested with only the pattern-matching case, so the guard was never
*failed* in any test. swift-coverage correctly flagged the `else` body as uncovered.

---

## 4. `switch` — cases, `default`, `where` clauses, comma-separated patterns

**Fixture:** `PatternMatching.swift` — `classify`, `isNonRectangular`

```swift
switch shape {
case .circle(let radius) where radius > 10: "large circle"
case .circle: "small circle"
default: "not a circle"
}
```

**Required:** one obligation per `case` (or `default`), matched independently. A `where` clause is
just part of that case's own condition — it doesn't split the case into two obligations, and doesn't
require the guard itself to have failed at least once.

```swift
switch shape {
case .square, .circle: true
default: false
}
```

**Comma-separated patterns sharing one body are a single obligation.** Reaching the shared body via
*either* pattern satisfies it — swift-coverage does not require each alternative pattern to have
been the one that matched.

**Verified:** `classify` fully exercised across all three cases (including the `where`-guarded one,
tested both true and false). `isNonRectangular` deliberately exercised via only the `.square` half of
its comma pattern — correctly marked covered, confirming the shared-obligation behavior rather than
flagging `.circle` as a separate untested alternative.

---

## 5. `do` / `try` / `catch` — multiple typed and pattern catch clauses

**Fixture:** `ErrorHandling.swift` — `run`

```swift
do {
    let value = try perform()
    return "ok: \(value)"
} catch TortureError.validation(let message) {
    ...
} catch TortureError.network {
    ...
} catch {
    ...
}
```

**Required:** one obligation for the `do` body (the success path) and one **independent** obligation
per `catch` clause, however many there are and whatever they match on (typed, pattern-bound, or
catch-all).

**Verified:** deliberately exercised the success path and only the `.validation` clause.
`.network` and the catch-all were correctly flagged as uncovered, independently of each other —
confirming catch clauses aren't treated as a single shared obligation.

---

## 6. `defer`

**Fixture:** `ErrorHandling.swift` — `withCleanup`

**Required:** nothing. `defer` has exactly one outcome — it always runs when its scope exits — so
there is no alternative to require coverage of. swift-coverage has no `LogicBranch` kind for `defer`
at all; a function's only obligations come from whatever actual conditionals it also contains.

**Verified:** `withCleanup` produces exactly 2 obligations (its `if`/`else`), not 3.

---

## 7. `while`, `repeat`-`while`, `for`-`in` (with `where`)

**Fixture:** `Loops.swift`

**Required:** one obligation — the loop body ran at least once.

**Not required:** a **zero-iteration** execution (the condition false on first check, for `while`
and `for`-`in`) is never separately required. `repeat`-`while` doesn't even have this gap in
principle — its body runs at least once by construction, so "zero iterations" isn't a reachable
outcome to begin with.

**`for`-`in ... where`:** the `where` clause filters which elements reach the body, but still
produces only the one "loop body entered" obligation — swift-coverage doesn't require the filter to
have both included and excluded at least one element.

**Verified:** `countDown` and `sumEvenNumbers` deliberately never called in a way that skips the
loop entirely; swift-coverage did not flag this (because nothing requires it — this is a documented
non-promise, not an unverified gap).

---

## 8. Optional fallbacks (`??`), optional chaining (`?.`), and the ternary operator (`?:`)

**Fixture:** `Optionals.swift`

**The ternary operator (`cond ? a : b`) gets one obligation per side** — `then` and `else`,
independently matched, exactly like `if`/`else`. `sizeLabel` was deliberately exercised on only the
`then` side; swift-coverage correctly flagged `else` as uncovered.

**`??`: one obligation per `??`** — the fallback (right-hand side) only.

**Not required:** the "left-hand side was non-nil" path has no obligation.

**Chained `??` are independent.** `a ?? b ?? "neither"` parses right-associatively as
`a ?? (b ?? "neither")`; each `??` gets its own obligation, matched to its own fallback's source
span. Reaching the outer fallback (evaluating `b ?? "neither"` at all, because `a` was nil) does
**not** imply reaching the inner one (which additionally requires `b` to be nil).

**Optional chaining (`?.`) has no obligation at all** — there is no `LogicBranch` kind for it.
`person?.address?.street` produces zero required branches on its own; the surrounding `??` (if any)
is the only obligation.

**Verified:** `firstNonNil` deliberately tested with `a` nil and `b` non-nil — swift-coverage
correctly marked the outer `??`'s obligation covered and the inner one's uncovered, on the same
source line, confirming they're tracked independently rather than as one obligation per statement.

---

## 9. Result builders (`@resultBuilder`, and by the same mechanism SwiftUI's `@ViewBuilder`)

**Fixture:** `ResultBuilder.swift` — a custom minimal `@resultBuilder` (`StringBuilder`), chosen over
`@ViewBuilder` specifically so this stays plain-macOS/Linux buildable with no Xcode/SwiftUI
dependency, while exercising the identical compiler mechanism: an `if`/`else` inside a
builder-annotated function body compiles to `buildEither(first:)`/`buildEither(second:)` calls; a
bare `if` compiles to `buildOptional(_:)`.

**Required:** exactly the same as an ordinary `if`/`else` — the `@resultBuilder` attribute changes
nothing about *detection*, since parsing happens before the result-builder transform.

**This was the one open question real compilation was needed to answer:** does the *compiler's own*
coverage-region emission for a builder-transformed branch still land at the branch's original source
position, surviving the rewrite into nested `buildEither`/`buildOptional` calls? **Answered: yes.**
`greeting`'s `if`/`else` and bare `if` were all correctly matched to covered/uncovered exactly as
written, with no positional drift. This directly supersedes an earlier, unrelated bug where a
*different* code path (shorthand computed-property getters, incidentally the shape of every SwiftUI
`body`) corrupted position tracking — that bug was in swift-coverage's own AST handling, fixed
before this fixture existed, and this result confirms result-builder transformation itself was never
the problem.

**Caveat:** only verified for a custom `@resultBuilder` with `buildBlock`/`buildEither`/
`buildOptional`. SwiftUI's `@ViewBuilder` uses the identical mechanism and this result should
transfer, but hasn't been separately verified against real SwiftUI compilation in this repo.

---

## 10. Macro expansions

**Fixture:** `Macros.swift`, `TortureMacros/StringifyMacro.swift` — a real `@freestanding(expression)`
macro (Apple's canonical `#stringify` example) with its own compiler-plugin target, not a
hypothetical.

**Two separate, independently-verified claims:**

**(a) A macro invocation's surrounding code is unaffected.** swift-coverage parses only the source
text present in the file; a macro's *expansion* (the code it generates at compile time) never
exists as text anywhere swift-coverage reads. `MacroUsage.describe`'s `if`/implicit-else, which
contains a `#stringify(n)` call inside its body, was detected and matched with zero surprises — the
macro invocation is syntactically inert as far as branch detection is concerned. It neither hides
branches around it nor requires anything additional.

**(b) A custom macro's own implementation is entirely outside swift-coverage's reach — and this is
the one place a fixture prediction was wrong.** `StringifyMacro.expansion`'s own `guard let argument
= ... else { fatalError(...) }` showed up in the report as **uncovered, with no coverage data for
its file at all** — not because it wasn't tested, but because it *cannot* be tested by `swift test`
in the normal sense. A macro implementation runs as a separate compiler-plugin process invoked by
`swiftc` during *compilation*, not as part of the test binary `swift test` instruments and executes.
No number of macro invocations across a test suite will ever mark that guard covered. If a project
ships custom macros, their own logic needs to be tested by a **separate, direct unit test of the
macro implementation itself** (SwiftSyntaxMacrosTestSupport's `assertMacroExpansion`, or equivalent)
— swift-coverage has no visibility into that process and cannot substitute for it. This is worth
`// swift-coverage:ignore`-ing explicitly in a real project rather than left to silently fail.

---

## 11. `#if` / `#elseif` / `#else` conditional compilation

**Fixture:** `ConditionalCompilation.swift` — `platformName`, `describeCount`

**Required:** nothing, for the `#if` itself, and this isn't a gap — it's structurally correct.
Unlike a runtime `if`, the clauses `#if` doesn't select for a given build **don't exist in that
binary at all**; there is no coverage region a `#else` branch that wasn't compiled could ever
produce, on any platform, in any test run. Requiring it would be requiring the impossible.

**A normal `if` living inside an `#if`-selected block is detected and required exactly as if the
`#if` weren't there** — swift-coverage doesn't skip descending into conditional-compilation blocks,
it only declines to treat `#if` itself as a branch.

**Verified:** `describeCount`'s inner `if` (inside `#if os(macOS)`) was detected and required
normally; the `#if`/`#elseif`/`#else` structure around it produced zero obligations of its own.

---

## 12. `if #available`

**Fixture:** `ConditionalCompilation.swift` — `modernAPIDescription`

**Required:** treated exactly like any other `if`/`else` — one obligation per body.
`#available(...)` is just another kind of condition inside an ordinary `IfExprSyntax`; nothing about
availability checking is specially modeled.

**A real, honest limitation this fixture surfaces rather than hides:** a version-gated `if
#available(macOS 14, *) { modern } else { legacy }` can only have its `else` exercised by a test
*running on an OS below that check* — which a single CI runner or dev machine often can't provide
for both sides at once. swift-coverage has no special case for this; it reports the untested side
as uncovered exactly like any other gap, which is arguably correct (the code path genuinely wasn't
exercised) but is worth knowing going in, since the fix isn't "write a better test," it's "run on
multiple OS versions or suppress it."

**Verified:** deliberately left with only the "modern" path exercised (the only one reachable on
the machine this suite runs on); swift-coverage correctly flagged `else` as uncovered.

---

## Summary table

| Construct | Obligation(s) | Not required | Confidence when matched |
|---|---|---|---|
| `if` / `if`-`else` | 1 per body present | condition-false path if no `else` written | high |
| `if a && b` / `if a \|\| b` | 1 per body (whole condition) | each operand's individual outcome | high |
| `if case` | 1 per body present | — (same as plain `if`) | high |
| `guard` / `guard case let` | 1 (`else` body) | the success/fallthrough path | high |
| `switch` case / `default` | 1 each, independent | — | medium (inferred) |
| `switch case ... where` | 1 (shared with the case) | the guard having failed at least once | medium (inferred) |
| `switch case A, B:` | 1 (shared) | each pattern individually matching | medium (inferred) |
| `catch` (each clause) | 1 each, independent | — | high |
| `defer` | 0 | n/a — not a decision point | n/a |
| `while` / `for`-`in` | 1 (body entered) | zero-iteration execution | high |
| `repeat`-`while` | 1 (body entered) | n/a — zero iterations isn't possible | high |
| `for-in ... where` | 1 (body entered) | filter both including and excluding something | high |
| ternary `?:` | 1 per side (`then`/`else`) | — | high |
| `??` | 1 (fallback), each `??` in a chain independent | the non-nil path | high |
| `?.` optional chaining | 0 | n/a — not tracked at all | n/a |
| `@resultBuilder`/`@ViewBuilder` branches | same as the underlying `if`/`switch` | — (verified, not assumed) | same as underlying construct |
| macro invocation (call site) | same as surrounding code | — (macro is syntactically inert) | same as surrounding code |
| macro implementation (own logic) | **none, ever** | requires a separate macro-expansion unit test | n/a — always `file_not_instrumented` |
| `#if`/`#elseif`/`#else` | 0 | n/a — untaken clauses don't exist in the binary | n/a |
| `if #available` | 1 per body present | the side unreachable on the test runner's OS | high |

## What would need to change to claim classical branch coverage

Per §1 and this table, the gap between "every explicit alternative code path" (what's implemented)
and classical two-outcome branch coverage is concentrated in exactly four places: compound
`&&`/`||` conditions (§1), a bare `if`'s condition-false path (demonstrated by `describeCount`'s
inner `if` in §11 — reached via `n > 1` but never via the implicit "skip it" path), a `guard`'s
success path (§3), and loop zero-iterations (§7). Closing all four was scoped out for now in favor
of this specification being accurate about the current, smaller promise — see the README's "What
this doesn't check (yet)" section.
