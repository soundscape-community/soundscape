//
//  GlyphSound.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//


import CoreLocation

struct GlyphSound: Sound {
    private let asset: StaticAudioEngineAsset
    let type: SoundType
    var description: String { "[\(asset.name)]" }
    var content: SoundContent { .asset(asset.audioAsset) }

    init(_ asset: StaticAudioEngineAsset, type: SoundType = .standard) {
        self.asset = asset
        self.type = type
    }

    init(_ asset: StaticAudioEngineAsset, at: CLLocation) {
        self.init(asset, type: .localized(AudioCoordinate(at), .ring))
    }

    init(_ asset: StaticAudioEngineAsset, compass: Double) {
        self.init(asset, type: .compass(compass, .ring))
    }

    init(_ asset: StaticAudioEngineAsset, direction: Double) {
        self.init(asset, type: .relative(direction, .ring))
    }
}
