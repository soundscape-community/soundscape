//
//  URLResourceIdentifier.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

enum URLResourceIdentifier {
    case gpx
    case route

    init?(pathExtension: String) {
        switch pathExtension.lowercased() {
        case "gpx": self = .gpx
        case "soundscape": self = .route
        default: return nil
        }
    }
}
