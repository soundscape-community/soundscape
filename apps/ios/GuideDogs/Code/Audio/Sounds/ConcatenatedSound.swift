//
//  ConcatenatedSound.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//


final class ConcatenatedSound: Sound {
    let type: SoundType
    
    let description: String
    
    let concatenatedSounds: [Sound]
    
    let layerCount: Int = 1
    
    
    init?(_ sounds: Sound...) {
        guard sounds.count > 0 else {
            return nil
        }
        
        self.concatenatedSounds = sounds
        
        // All sub-sounds must have only a single channel
        guard sounds.allSatisfy({ $0.layerCount == 1 }) else {
            return nil
        }
        
        // All sub-sounds must have analogous sound types
        let type = sounds[0].type
        let typesMatch = sounds.allSatisfy({ channel in
            switch (channel.type, type) {
            case (.standard, .standard),
                 (.localized, .localized),
                 (.relative, .relative),
                 (.compass, .compass):
                return true
            default:
                return false
            }
        })
        
        guard typesMatch else {
            return nil
        }
        
        self.type = type
        
        if let first = sounds.first?.description {
            description = "[\(sounds[sounds.startIndex + 1 ..< sounds.endIndex].reduce(first) { $0 + ", " + $1.description })]"
        } else {
            description = "[]"
        }
    }
    
    var content: SoundContent { .sequence(concatenatedSounds) }
}
