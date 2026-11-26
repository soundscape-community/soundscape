//
//  BeaconSound.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import CoreLocation

final class BeaconSound<T: DynamicAudioEngineAsset>: Sound {
    let type: SoundType
    let content: SoundContent
    var description: String { String(describing: T.self) }

    private init?(at location: CLLocation, type: SoundType, includeStartMelody: Bool, includeEndMelody: Bool, wand: WandBeaconPolicy? = nil) {
        let assets = T.allCases.map { $0.audioAsset }
        guard let first = assets.first else { return nil }
        let reference = AudioCoordinate(location)
        self.type = type
        self.content = .beacon(AdaptiveBeacon(
            assets: assets, reference: reference, beats: T.beatsInPhrase,
            intro: includeStartMelody ? BeaconAccents.start.audioAsset : nil,
            outro: includeEndMelody ? BeaconAccents.end.audioAsset : nil,
            select: { listener, heading, angle, focus in
                if let wand {
                    let bearing = listener?.bearing(to: reference) ?? 0
                    return (first, wand.volume(heading: heading, bearing: bearing, angle: angle, focus: focus))
                }
                guard let selector = T.selector else { return (first, 1) }
                if let value = selector(.location(listener, reference)) { return (value.asset.audioAsset, value.volume) }
                guard let listener,
                      let value = selector(.heading(heading, listener.bearing(to: reference), angle)) else { return nil }
                return (value.asset.audioAsset, value.volume)
            }))
    }

    convenience init?(_ assetType: T.Type, at location: CLLocation, isLocalized: Bool = true,
                      includeStartMelody: Bool = false, includeEndMelody: Bool = false, wand: WandBeaconPolicy? = nil) {
        self.init(at: location, type: isLocalized ? .localized(AudioCoordinate(location), .ring) : .standard,
                  includeStartMelody: includeStartMelody, includeEndMelody: includeEndMelody, wand: wand)
    }

    convenience init?(_ assetType: T.Type, at location: CLLocation, direction: Double,
                      includeStartMelody: Bool = false, includeEndMelody: Bool = false) {
        self.init(at: location, type: .relative(direction, .ring),
                  includeStartMelody: includeStartMelody, includeEndMelody: includeEndMelody)
    }

    convenience init?(_ assetType: T.Type, at location: CLLocation, compass: Double,
                      includeStartMelody: Bool = false, includeEndMelody: Bool = false) {
        self.init(at: location, type: .compass(compass, .ring),
                  includeStartMelody: includeStartMelody, includeEndMelody: includeEndMelody)
    }
}
