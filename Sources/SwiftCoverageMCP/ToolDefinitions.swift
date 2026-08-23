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
        "description": .string("Passed through to `swift test --filter` (ignored when skip_tests is true)."),
    ])

    static let checkCoverage = Tool(
        name: "check_coverage",
        description: """
            Runs the package's test suite (unless skip_tests is set) and checks whether every \
            branch of its logic — every if/else, guard, switch case, loop, catch clause, and \
            ternary/?? alternative — was reached by a test. Unlike a line/statement coverage \
            percentage, this fails on a single untested branch even if the overall statement \
            coverage looks high. Returns the full report as JSON, including `passes` and, for \
            each logic unit, each branch's covered/suppressed state. A struct or type with no \
            branching logic never appears here — it has nothing to require coverage of. \
            Declarations or branches marked with `// swift-coverage:ignore`, \
            `// swift-coverage:ignore-branch`, or `// swift-coverage:ignore-file` are excluded.
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
            test: file, line, enclosing function, and a short label (e.g. "case .vip", "else", \
            "guard else"). Use this to get a concrete to-do list without the full report.
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
