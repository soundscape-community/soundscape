//
//  IntersectionRoadId.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation

struct IntersectionRoadId: Codable {
    let id: String

    init(withId id: String) {
        self.id = id
    }
}
