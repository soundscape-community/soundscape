// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SoundscapeCommon",
    products: [
        .library(
            name: "SoundscapeCoreDataStructures",
            targets: ["SoundscapeCoreDataStructures"]
        ),
    ],
    targets: [
        .target(
            name: "SoundscapeCoreDataStructures"
        ),
        .testTarget(
            name: "SoundscapeCoreDataStructuresTests",
            dependencies: ["SoundscapeCoreDataStructures"]
        ),
    ]
)
