//
//  ConcatenatedSound.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import AVFoundation

class ConcatenatedSound: Sound {
    var type: SoundType
    
    let description: String
    
    let concatenatedSounds: [Sound]
    
    let layerCount: Int = 1
    
    private var currentSoundIndex = 0
    
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
    
    func nextBuffer(forLayer index: Int) async -> AVAudioPCMBuffer? {
        guard index == 0 else { return nil }

        // Iterate current sound index until we produce a buffer or exhaust the list.
        while currentSoundIndex < concatenatedSounds.count {
            if let buffer = await concatenatedSounds[currentSoundIndex].nextBuffer(forLayer: 0) {
                return buffer
            }
            currentSoundIndex += 1
        }

        return nil
    }
    
    // old Promise-backed helper removed; logic replaced by async loop in `nextBuffer`.
}

extension ConcatenatedSound: SoundBase {
    /// Looks up the optional equalizer parameters for a given layer
    func equalizerParams(for layerIndex: Int) -> EQParameters? {
        guard layerIndex == 0 else {
            return nil
        }
        
        return concatenatedSounds.compactMap({ $0.equalizerParams(for: 0) }).first
    }
}
