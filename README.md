# swift-coverage

A Swift CLI that makes test coverage **mandatory for logic, not for lines**.

Tools like SonarQube report a coverage *percentage* — "80% of statements ran" — and gate CI on
that threshold. A percentage is easy to game and easy to hide behind: one untested `case .vip`
in a pricing switch can sit right next to ninety well-tested lines and never move the number
enough to fail the build. `swift-coverage` instead finds every individual branch in your code —
every `if`/`else`, `guard`, `switch` case, loop, `catch` clause, and ternary/`??` alternative —
and fails if **any single one** of them was never reached by `swift test`. Plain data types need
no special treatment: a struct with only stored properties has no branches, so it's never asked
to be covered in the first place.

It's built for use in an agentic SDLC: a coding agent can run `swift-coverage` after writing
tests and get a deterministic pass/fail plus a machine-readable list of exactly which logic paths
still need a test — not a percentage it has to interpret.

Built with [SwiftSyntax](https://github.com/swiftlang/swift-syntax),
[swift-argument-parser](https://github.com/apple/swift-argument-parser), and the
[MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk), following the shape of
[fummicc1/swift-complexity](https://github.com/fummicc1/swift-complexity) as a starting point.

## Install

```sh
git clone <this repo>
cd swift-coverage
swift build -c release
cp .build/release/swift-coverage /usr/local/bin/
cp .build/release/swift-coverage-mcp /usr/local/bin/   # only if you want the MCP server too
```

## Usage

```sh
# Run the test suite with coverage enabled, then check every logic branch was reached.
swift-coverage path/to/YourPackage

# Machine-readable output for an agent or CI step to parse.
swift-coverage path/to/YourPackage --format json

# Re-check the last coverage run without re-running `swift test`.
swift-coverage path/to/YourPackage --skip-tests

# Report without failing the command (useful for a first adoption pass).
swift-coverage path/to/YourPackage --no-fail

# Narrow analysis to (or away from) parts of the tree.
swift-coverage path/to/YourPackage --include "Sources/Core/**" --exclude "**/Generated/**"
```

Run `swift-coverage --help` for the full option list.

### Exit codes

| Code | Meaning |
|---|---|
| `0` | Every required logic branch was covered. |
| `1` | The build and tests succeeded, but at least one required logic branch was not. |
| `2` | `swift test` itself failed (a real test failure, not a coverage gap). |
| `3` | Tool/usage error — bad path, undecodable coverage data, etc. |

Codes `1` and `2` are kept distinct on purpose: an agent (or a CI step) can tell "the code is
broken" apart from "the code works but isn't proven by a test" and react differently.

## What counts as a "logic unit"

Any function, initializer, deinitializer, or computed-property accessor that contains at least
one branch. A declaration with zero branches (a stored property, a struct's memberwise fields, a
one-line pass-through) never becomes a logic unit — this is how plain data types are excluded
without any type-level special-casing; they simply never generate a coverage requirement.

Each logic unit is broken into its individual **branches**:

- `if` / `else` (each `else if` recurses as its own pair)
- `guard ... else`
- each `switch` `case` (including `default`)
- `for`, `while`, `repeat`-`while` loop bodies
- `catch` clauses
- both sides of a ternary `cond ? a : b`
- the right-hand side of `??`

A branch inside a closure literal counts toward its *enclosing* declaration (Swift has no syntax
to make a closure its own independently-tested unit). A nested local function, computed property,
or type gets its own logic unit and isn't double-counted.

## Marking an intentionally-untested path

```swift
// swift-coverage:ignore
func generatedPassthrough() -> Int { ... }          // whole declaration excluded

func normalize(_ value: Int) -> Int {
    // swift-coverage:ignore-branch
    guard value >= 0 else {                          // just this branch excluded
        preconditionFailure("unreachable by construction")
    }
    return value
}
```

```swift
// swift-coverage:ignore-file
// (must be the very first line of the file)
```

All three are exact `//` line comments — never `///`, so documentation is never mistaken for a
directive — placed directly above the declaration or branch they suppress (or, for a ternary/`??`,
above the statement it's part of).

## How branch matching works

`swift-coverage` runs `swift test --enable-code-coverage`, then reads the coverage export JSON
SwiftPM already produces (`swift test --show-codecov-path`) — no direct `llvm-cov` invocation or
manual `.xctest` binary discovery needed. That export lists, per function, every source region
the compiler instrumented along with its execution count. For each branch found by parsing your
source with SwiftSyntax, `swift-coverage` finds the innermost coverage region containing that
branch's start position and reads its count: zero means the branch never ran.

Ternary and `??` expressions need one extra step: `SwiftParser` alone leaves `?:` and infix
operators as unresolved sequence expressions, so `swift-coverage` folds each file's syntax tree
with `SwiftOperators` before walking it — otherwise `TernaryExprSyntax`/`InfixOperatorExprSyntax`
nodes never appear.

If a branch's file has no coverage data at all (most often because it wasn't compiled into any
tested target), it's reported as uncovered too, not silently skipped — "no evidence this ran" is
exactly the kind of gap a percentage threshold can hide.

## Example

See `Examples/DemoPackage` for a small package with a fully-covered function, a deliberately
untested `switch` case, an `// swift-coverage:ignore-branch`-annotated guard, and a plain data
struct that's excluded automatically. From this repo root:

```sh
swift build -c release
.build/release/swift-coverage Examples/DemoPackage
```

## Xcode-project / iOS-only packages

Some packages can't be built by a bare `swift test` on macOS at all — an iOS-only package, or one
that's only buildable through an Xcode project/workspace (e.g. an SPM package wrapped by a
generated `.xcodeproj`, with per-target Xcode-only schemes). For those, pass `--scheme` instead of
letting swift-coverage default to `swift test`:

```sh
swift-coverage path/to/YourPackage \
  --scheme YourModuleTests \
  --destination 'platform=iOS Simulator,name=iPhone 17' \
  --include "Sources/YourModule/**"
```

This runs `xcodebuild test -scheme ... -derivedDataPath ...` instead of `swift test`, then
extracts coverage the same way SwiftPM does under the hood: it locates the raw `Coverage.profdata`
`xcodebuild` wrote under `-derivedDataPath`, finds the scheme's `.xctest` binary, and runs `xcrun
llvm-cov export` against them — the exact same region-level JSON `swift test`'s own coverage
export produces, so every downstream matching/reporting path is identical either way.
(`xcodebuild`'s own coverage reporting, `xcrun xccov view --report --json`, is function-level only
— too coarse for this tool's branch-level matching, which is why this doesn't just use that.)

Other options for this mode: `--xcode-project`/`--xcode-workspace` (explicit paths; omitted lets
`xcodebuild` auto-detect), `--derived-data-path` (defaults to `<path>/.build/swift-coverage-xcode`,
kept around so repeat runs are incremental rather than full rebuilds), and `--filter` (mapped to
`xcodebuild -only-testing:` in this mode, instead of `swift test --filter`). List available
simulators with `xcrun simctl list devices available`.

## MCP server

`swift-coverage-mcp` exposes the same analysis over the
[Model Context Protocol](https://modelcontextprotocol.io) (stdio transport), for agents and
editors that call tools through MCP rather than a shell. It's a thin wrapper — same
`SwiftCoverageCore` library, same coverage matching — over three tools:

| Tool | Runs tests? | Returns |
|---|---|---|
| `check_coverage` | yes (unless `skip_tests`) | The full report: `passes`, every logic unit, every branch's covered/suppressed state. |
| `list_uncovered_branches` | yes (unless `skip_tests`) | Just the branches still needing a test — file, line, unit, label. |
| `list_logic_units` | no | Every logic unit and its branches, parsed from source only — for previewing what a change will require coverage for. |

All three take `path` (required), plus `include`/`exclude` globs; the two that run tests also
take `skip_tests`, `test_filter`, and the `scheme`/`destination`/`xcode_project`/`xcode_workspace`/
`derived_data_path` options for the Xcode-project path described above. `check_coverage`
additionally takes `format` (`json` or `text`).

Register it with an MCP client by pointing it at the built binary, e.g. in Claude Code's
`.mcp.json`:

```json
{
  "mcpServers": {
    "swift-coverage": { "command": "/usr/local/bin/swift-coverage-mcp" }
  }
}
```

`check_coverage`/`list_uncovered_branches` calls are serialized process-wide (`CoverageRunGate`):
MCP dispatches tool calls concurrently, and two overlapping `swift test --enable-code-coverage`
runs against the same package would otherwise race on SwiftPM's shared `.build` state.

## CI

```yaml
- name: Check logic coverage
  run: swift-coverage . --format json > coverage-report.json || (cat coverage-report.json && exit 1)
```

## Known limitations (v1)

- Source discovery defaults to everything under `Sources/`; a package with source directories
  elsewhere needs `--include`.
- Column matching assumes ASCII-width source lines; a branch on a line with certain wide Unicode
  characters near its start could match imprecisely.
