// swift-tools-version: 6.0
// Copyright (c) Soundscape Community Contributers.

import PackageDescription

let package = Package(
    name: "SoundscapeCommon",
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
            name: "SSDataDomain",
            targets: ["SSDataDomain"]
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
            name: "SSDataDomain",
            dependencies: ["SSGeo"]
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
            name: "SSDataDomainTests",
            dependencies: ["SSDataDomain"]
        ),
    ]
)
