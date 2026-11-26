//
//  Sounds.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation

struct Sounds {
    static let empty = Sounds()
    let soundArray: [any Sound]
    let availableTail: (@MainActor () -> [any Sound])?

    var isEmpty: Bool { soundArray.isEmpty }

    init(_ sounds: [any Sound] = [], availableTail: (@MainActor () -> [any Sound])? = nil) {
        soundArray = sounds
        self.availableTail = availableTail
    }

    init(_ sound: any Sound) {
        self.init([sound])
    }
}
