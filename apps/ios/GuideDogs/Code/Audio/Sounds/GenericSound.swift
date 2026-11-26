//
//  GenericSound.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import CoreLocation

enum GenericAudioSource: Sendable {
    case file(URL)
    case bundle(StaticAudioEngineAsset)
}

/// A simplified `Sound` object for playing simple audio assets in standard 2D audio
final class GenericSound: Sound {
    let type: SoundType
    
    let source: GenericAudioSource
    
    /// Channel count for the generic sound. `GenericSound`s always have only 1 channel
    let layerCount: Int = 1
    
    var content: SoundContent {
        switch source {
        case .file(let url): return .asset(.file(url))
        case .bundle(let asset): return .asset(asset.audioAsset)
        }
    }
    
    /// Human-readable description of the sound
    var description: String {
        switch source {
        case .file(let url):
            return "{\(url.lastPathComponent)}"
        case .bundle(let asset):
            return "{\(asset.name)}"
        }
    }
    
    /// Initialize a standard 2D sound for an audio asset
    ///
    /// - Parameter asset: Audio asset to load
    init(_ asset: StaticAudioEngineAsset) {
        source = .bundle(asset)
        self.type = .standard
    }
    
    /// Initialize a localized 3D sound for an audio asset
    ///
    /// - Parameters:
    ///   - asset: The asset to load
    ///   - at: The GPS location the sound is localized with
    init(_ asset: StaticAudioEngineAsset, at: CLLocation) {
        source = .bundle(asset)
        type = .localized(AudioCoordinate(at), .ring)
    }
    
    /// Initialize a relative 3D sound for an audio asset
    ///
    /// - Parameters:
    ///   - asset: The asset to load
    ///   - direction: The relative direction the sound should be localized in (relative to the user)
    init(_ asset: StaticAudioEngineAsset, direction: CLLocationDirection) {
        source = .bundle(asset)
        type = .relative(direction, .ring)
    }
    
    /// Initialize a 3D sound in a compass direction for an audio asset
    ///
    /// - Parameters:
    ///   - asset: The asset to load
    ///   - compass: The compass direction the sound should be localized in (relative to the user)
    init(_ asset: StaticAudioEngineAsset, compass: CLLocationDirection) {
        source = .bundle(asset)
        type = .compass(compass, .ring)
    }
    
    /// Initialize a standard 2D sound for a downloaded audio file
    ///
    /// - Parameter asset: Audio asset to load
    init(_ file: URL) {
        source = .file(file)
        self.type = .standard
    }
    
    /// Initialize a localized 3D sound for a downloaded audio file
    ///
    /// - Parameters:
    ///   - asset: The asset to load
    ///   - at: The GPS location the sound is localized with
    init(_ file: URL, at: CLLocation) {
        source = .file(file)
        type = .localized(AudioCoordinate(at), .ring)
    }
    
    /// Initialize a relative 3D sound for a downloaded audio file
    ///
    /// - Parameters:
    ///   - asset: The asset to load
    ///   - direction: The relative direction the sound should be localized in (relative to the user)
    init(_ file: URL, direction: CLLocationDirection) {
        source = .file(file)
        type = .relative(direction, .ring)
    }
    
    /// Initialize a 3D sound in a compass direction for a downloaded audio file
    ///
    /// - Parameters:
    ///   - asset: The asset to load
    ///   - compass: The compass direction the sound should be localized in (relative to the user)
    init(_ file: URL, compass: CLLocationDirection) {
        source = .file(file)
        type = .compass(compass, .ring)
    }
    
}
