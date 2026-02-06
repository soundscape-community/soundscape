// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SoundscapeCommon",
    products: [
        .library(
            name: "SSDataStructures",
            targets: ["SSDataStructures"]
        ),
    ],
    targets: [
        .target(
            name: "SSDataStructures"
        ),
        .testTarget(
            name: "SSDataStructuresTests",
            dependencies: ["SSDataStructures"]
        ),
    ]
)
