// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "MindPalantir",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "MindPalantir",
            path: "Sources"
        ),
    ]
)
