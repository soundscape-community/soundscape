// swift-tools-version: 6.1
// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import PackageDescription

let package = Package(
    name: "SoundscapeAndroid",
    products: [.library(name: "CoreLocationCompat", targets: ["CoreLocationCompat"])],
    targets: [.target(name: "CoreLocationCompat")]
)
