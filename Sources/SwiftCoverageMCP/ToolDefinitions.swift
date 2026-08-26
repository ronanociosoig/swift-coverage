import MCP

/// Defines all MCP tools exposed by the swift-coverage server.
enum ToolDefinitions {
    static let allTools: [Tool] = [
        checkCoverage,
        listUncoveredBranches,
        listLogicUnits,
    ]

    private static let pathProperty: Value = .object([
        "type": .string("string"),
        "description": .string("Path to the Swift package (directory containing Package.swift)."),
    ])

    private static let includeProperty: Value = .object([
        "type": .string("array"),
        "items": .object(["type": .string("string")]),
        "description": .string("Glob(s), relative to the package root, to restrict analysis to."),
    ])

    private static let excludeProperty: Value = .object([
        "type": .string("array"),
        "items": .object(["type": .string("string")]),
        "description": .string("Glob(s), relative to the package root, to exclude from analysis."),
    ])

    private static let skipTestsProperty: Value = .object([
        "type": .string("boolean"),
        "default": .bool(false),
        "description": .string(
            "Reuse the coverage data from the last `swift test --enable-code-coverage` run instead of "
                + "running the suite again. Fails if no such run has happened yet."
        ),
    ])

    private static let testFilterProperty: Value = .object([
        "type": .string("string"),
        "description": .string(
            "Passed through to `swift test --filter`, or (with scheme set) to `xcodebuild -only-testing:`. "
                + "Ignored when skip_tests is true."
        ),
    ])

    private static let schemeProperty: Value = .object([
        "type": .string("string"),
        "description": .string(
            "Xcode scheme to test via `xcodebuild` instead of `swift test` \u{2014} for a package that's "
                + "iOS-only or otherwise can't be built by a bare `swift test` on macOS. Requires destination."
        ),
    ])

    private static let destinationProperty: Value = .object([
        "type": .string("string"),
        "description": .string(
            "xcodebuild destination, e.g. 'platform=iOS Simulator,name=iPhone 17'. Required when scheme is set."
        ),
    ])

    private static let xcodeProjectProperty: Value = .object([
        "type": .string("string"),
        "description": .string("Explicit .xcodeproj path, passed to xcodebuild -project. Omit to auto-detect."),
    ])

    private static let xcodeWorkspaceProperty: Value = .object([
        "type": .string("string"),
        "description": .string("Explicit .xcworkspace path, passed to xcodebuild -workspace."),
    ])

    private static let derivedDataPathProperty: Value = .object([
        "type": .string("string"),
        "description": .string(
            "Derived data path for a scheme run, so its Coverage.profdata can be found afterward. "
                + "Defaults to <path>/.build/swift-coverage-xcode."
        ),
    ])

    private static let diffBaseProperty: Value = .object([
        "type": .string("string"),
        "description": .string(
            "Only require coverage for logic added or changed since this git ref (e.g. 'origin/main'), "
                + "computed against their merge-base so commits landed on the ref afterward don't count. Use "
                + "this for PR-review-style feedback — what new logic in the current change is uncovered — "
                + "rather than every pre-existing gap in the whole codebase."
        ),
    ])

    static let checkCoverage = Tool(
        name: "check_coverage",
        description: """
            Runs the package's test suite (unless skip_tests is set) and checks whether every \
            branch of its logic — every if/else, guard, switch case, loop, catch clause, and \
            ternary/?? alternative — was reached by a test. Unlike a line/statement coverage \
            percentage, this fails on a single untested branch even if the overall statement \
            coverage looks high. Returns the full report as JSON, including `passes` and, for \
            each logic unit, each branch's status/confidence/evidence/suppressed state (see \
            SEMANTICS.md \u{2014} status is covered/uncovered/unknown, confidence and evidence make \
            the heuristic nature of the coverage match explicit rather than hiding it behind a bare \
            true/false). A struct or type with no \
            branching logic never appears here — it has nothing to require coverage of. \
            Declarations or branches marked with `// swift-coverage:ignore`, \
            `// swift-coverage:ignore-branch`, or `// swift-coverage:ignore-file` are excluded. \
            Set diff_base to scope the whole check to only logic added or changed since a git ref.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "required": .array([.string("path")]),
            "properties": .object([
                "path": pathProperty,
                "include": includeProperty,
                "exclude": excludeProperty,
                "skip_tests": skipTestsProperty,
                "test_filter": testFilterProperty,
                "scheme": schemeProperty,
                "destination": destinationProperty,
                "xcode_project": xcodeProjectProperty,
                "xcode_workspace": xcodeWorkspaceProperty,
                "derived_data_path": derivedDataPathProperty,
                "diff_base": diffBaseProperty,
                "format": .object([
                    "type": .string("string"),
                    "enum": .array([.string("json"), .string("text")]),
                    "default": .string("json"),
                    "description": .string("Output format (json recommended for programmatic use)."),
                ]),
            ]),
        ])
    )

    static let listUncoveredBranches = Tool(
        name: "list_uncovered_branches",
        description: """
            Same analysis as check_coverage, but returns just the branches that still need a \
            test: file, line, enclosing function, a short label (e.g. "case .vip", "else", \
            "guard else"), and a concrete suggestion (e.g. "Add a test calling Discount.tierName \
            with a value matching `case .vip`."). Use this to get a concrete to-do list without \
            the full report — well suited to an agent loop: call this, write a test for each \
            entry, rerun, repeat until empty. Set diff_base to scope that to-do list to only \
            logic added or changed since a git ref, e.g. for PR-review-style feedback on a branch \
            without flagging every pre-existing gap in the codebase at once.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "required": .array([.string("path")]),
            "properties": .object([
                "path": pathProperty,
                "include": includeProperty,
                "exclude": excludeProperty,
                "skip_tests": skipTestsProperty,
                "test_filter": testFilterProperty,
                "scheme": schemeProperty,
                "destination": destinationProperty,
                "xcode_project": xcodeProjectProperty,
                "xcode_workspace": xcodeWorkspaceProperty,
                "derived_data_path": derivedDataPathProperty,
                "diff_base": diffBaseProperty,
            ]),
        ])
    )

    static let listLogicUnits = Tool(
        name: "list_logic_units",
        description: """
            Parses the package's source (without running any tests) and lists every logic unit \
            \u{2014} each function, initializer, deinitializer, or computed property that contains \
            branching logic \u{2014} along with its branches. Useful for previewing what a change \
            will require test coverage for before writing tests, or for auditing which \
            declarations are suppressed. Files and declarations with no branching logic (plain \
            data types) are reported separately and require nothing.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "required": .array([.string("path")]),
            "properties": .object([
                "path": pathProperty,
                "include": includeProperty,
                "exclude": excludeProperty,
            ]),
        ])
    )
}
