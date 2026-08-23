// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DemoPackage",
    targets: [
        .target(name: "DemoPackage"),
        .testTarget(name: "DemoPackageTests", dependencies: ["DemoPackage"]),
    ]
)
