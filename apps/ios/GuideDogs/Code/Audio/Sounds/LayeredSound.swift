//
//  LayeredSound.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//


final class LayeredSound: Sound {
    let type: SoundType
    
    let description: String
    
    let layeredSounds: [Sound]
    
    let layerCount: Int
    
    init?(_ layeredSounds: Sound...) {
        guard layeredSounds.count > 0 else {
            return nil
        }
        
        self.layeredSounds = layeredSounds
        layerCount = layeredSounds.count
        
        // All sub-sounds must have only a single channel
        guard layeredSounds.allSatisfy({ $0.layerCount == 1 }) else {
            return nil
        }
        
        // All sub-sounds must have analogous sound types
        let type = layeredSounds[0].type
        let typesMatch = layeredSounds.allSatisfy({ channel in
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
        
        if let first = layeredSounds.first?.description {
            description = "[\(layeredSounds[layeredSounds.startIndex + 1 ..< layeredSounds.endIndex].reduce(first) { $0 + ", " + $1.description })]"
        } else {
            description = "[]"
        }
    }
    
    var content: SoundContent { .parallel(layeredSounds) }
}
