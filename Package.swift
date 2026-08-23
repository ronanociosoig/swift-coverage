// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "swift-coverage",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SwiftCoverageCore",
            targets: ["SwiftCoverageCore"]
        ),
        .executable(
            name: "swift-coverage",
            targets: ["SwiftCoverageCLI"]
        ),
        .executable(
            name: "swift-coverage-mcp",
            targets: ["SwiftCoverageMCP"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0"),
    ],
    targets: [
        .target(
            name: "SwiftCoverageCore",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftOperators", package: "swift-syntax"),
            ],
            path: "Sources/SwiftCoverageCore"
        ),
        .executableTarget(
            name: "SwiftCoverageCLI",
            dependencies: [
                "SwiftCoverageCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/SwiftCoverageCLI"
        ),
        .executableTarget(
            name: "SwiftCoverageMCP",
            dependencies: [
                "SwiftCoverageCore",
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: "Sources/SwiftCoverageMCP"
        ),
        .testTarget(
            name: "SwiftCoverageCoreTests",
            dependencies: [
                "SwiftCoverageCore",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ],
            path: "Tests/SwiftCoverageCoreTests",
            resources: [
                .copy("Fixtures")
            ]
        ),
    ]
)
