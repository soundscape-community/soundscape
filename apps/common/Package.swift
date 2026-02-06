// swift-tools-version: 6.0
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
    ],
    targets: [
        .target(
            name: "SSDataStructures"
        ),
        .target(
            name: "SSGeo"
        ),
        .testTarget(
            name: "SSDataStructuresTests",
            dependencies: ["SSDataStructures"]
        ),
        .testTarget(
            name: "SSGeoTests",
            dependencies: ["SSGeo"]
        ),
    ]
)
