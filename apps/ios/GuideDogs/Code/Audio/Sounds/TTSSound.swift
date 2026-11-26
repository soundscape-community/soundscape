//
//  TTSSound.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import CoreLocation

final class TTSSound: Sound {
    let type: SoundType
    let text: String
    var description: String { text }
    var content: SoundContent { .speech(text) }

    // MARK: Initializers
    
    /// Initialize a standard 2D sound for the text-to-speech
    ///
    /// - Parameter text: Text to render to speech
    init(_ text: String) {
        self.text = text
        self.type = .standard
    }
    
    /// Initialize a localized 3D sound for the text-to-speech
    ///
    /// - Parameters:
    ///   - text: Text to render to speech
    ///   - at: The GPS location the sound is localized with
    init(_ text: String, at: CLLocation) {
        self.text = text
        self.type = .localized(AudioCoordinate(at), .ring)
    }
    
    /// Initialize a relative 3D sound for the text-to-speech
    ///
    /// - Parameters:
    ///   - text: Text to render to speech
    ///   - direction: The relative direction the sound should be localized in (relative to the user)
    init(_ text: String, direction: CLLocationDirection) {
        self.text = text
        self.type = .relative(direction, .ring)
    }
    
    /// Initialize a 3D sound in a compass direction for the text-to-speech
    ///
    /// - Parameters:
    ///   - text: Text to render to speech
    ///   - compass: The compass direction the sound should be localized in (relative to the user)
    init(_ text: String, compass: CLLocationDirection) {
        self.text = text
        type = .compass(compass, .ring)
    }
    
}
