// swift-tools-version: 5.10
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "TortureTest",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0")
    ],
    targets: [
        .macro(
            name: "TortureMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "TortureTest",
            dependencies: ["TortureMacros"]
        ),
        .testTarget(
            name: "TortureTestTests",
            dependencies: ["TortureTest"]
        ),
    ]
)
