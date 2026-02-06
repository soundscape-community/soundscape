// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SSIndexAnalyzer",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/indexstore-db.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "SSIndexAnalyzer",
            dependencies: [
                .product(name: "IndexStoreDB", package: "indexstore-db"),
            ]
        ),
    ]
)
