// swift-tools-version: 6.1
// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import PackageDescription

let package = Package(
    name: "SoundscapeCommon",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "SSData", targets: ["SSData"])],
    dependencies: [
        .package(path: "../android"),
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.12.0")
    ],
    targets: [
        .target(name: "SSData", dependencies: [
            .product(name: "CoreLocationCompat", package: "android"),
            .product(name: "GRDB", package: "GRDB.swift")
        ]),
        .testTarget(name: "SSDataTests", dependencies: [
            "SSData",
            .product(name: "CoreLocationCompat", package: "android")
        ])
    ]
)
