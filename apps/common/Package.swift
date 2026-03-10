// swift-tools-version: 6.0
// Copyright (c) Soundscape Community Contributers.

import PackageDescription

let package = Package(
    name: "SoundscapeCommon",
    defaultLocalization: "en-US",
    products: [
        .library(
            name: "SSDataStructures",
            targets: ["SSDataStructures"]
        ),
        .library(
            name: "SSGeo",
            targets: ["SSGeo"]
        ),
        .library(
            name: "SSLanguage",
            targets: ["SSLanguage"]
        ),
        .library(
            name: "SSDataDomain",
            targets: ["SSDataDomain"]
        ),
        .library(
            name: "SSDataContracts",
            targets: ["SSDataContracts"]
        ),
    ],
    targets: [
        .target(
            name: "SSDataStructures"
        ),
        .target(
            name: "SSGeo"
        ),
        .target(
            name: "SSLanguage",
            dependencies: ["SSGeo"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "SSDataDomain",
            dependencies: ["SSDataStructures", "SSGeo"]
        ),
        .target(
            name: "SSDataContracts",
            dependencies: ["SSDataDomain", "SSGeo"]
        ),
        .testTarget(
            name: "SSDataStructuresTests",
            dependencies: ["SSDataStructures"]
        ),
        .testTarget(
            name: "SSGeoTests",
            dependencies: ["SSGeo"]
        ),
        .testTarget(
            name: "SSLanguageTests",
            dependencies: ["SSLanguage"]
        ),
        .testTarget(
            name: "SSDataDomainTests",
            dependencies: ["SSDataDomain"]
        ),
        .testTarget(
            name: "SSDataContractsTests",
            dependencies: ["SSDataContracts"]
        ),
    ]
)
