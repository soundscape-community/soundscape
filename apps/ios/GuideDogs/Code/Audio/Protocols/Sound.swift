//
//  Sound.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation

protocol Sound: Sendable, CustomStringConvertible {
    var type: SoundType { get }
    var content: SoundContent { get }
    var layerCount: Int { get }
}

extension Sound {
    var layerCount: Int { 1 }
}

enum SoundContent: Sendable {
    case asset(AudioAsset)
    case speech(String)
    case parallel([any Sound])
    case sequence([any Sound])
    case beacon(AdaptiveBeacon)
}

enum AudioAsset: Hashable, Sendable {
    case bundle(name: String, extension: String)
    case file(URL)
    case catalog(name: String, extension: String)
}

struct AdaptiveBeacon: Sendable {
    let assets: [AudioAsset]
    let reference: AudioCoordinate
    let beats: Int
    let intro: AudioAsset?
    let outro: AudioAsset?
    let select: @Sendable (AudioCoordinate?, Double?, Double, Double?) -> (AudioAsset, Float)?
}

enum WandBeaconPolicy: Sendable {
    case pulse(window: Double)
    case focus(window: Double, followsLocation: Bool)

    func volume(heading: Double?, bearing: Double, angle: Double, focus: Double?) -> Float {
        guard let heading else { return 0 }
        let target: Double
        let fullVolume: Double
        let window: Double
        switch self {
        case .pulse(let width): (target, fullVolume, window) = (bearing, angle, width)
        case .focus(let width, let followsLocation):
            guard let focus else { return 0 }
            (target, fullVolume, window) = (followsLocation ? bearing : focus, 15, width)
        }
        return Self.volume(heading: heading, bearing: target, fullVolume: fullVolume, window: window)
    }

    static func volume(heading: Double, bearing: Double, fullVolume: Double, window: Double) -> Float {
        let delta = abs((heading - bearing).truncatingRemainder(dividingBy: 360))
        let distance = min(delta, 360 - delta)
        guard distance > fullVolume else { return 1 }
        let fadeWidth = window / 2 - fullVolume
        guard fadeWidth > 0 else { return 0 }
        return Float(max(0, 1 - (distance - fullVolume) / fadeWidth))
    }
}

struct BeaconTiming: Sendable {
    let intro: Int64
    let phrase: Int64
    let beats: Int64

    func next(after frame: Int64?) -> (start: Int64, offset: Int64) {
        guard let frame, frame >= intro, beats > 0, phrase >= beats else { return (intro, 0) }
        let elapsed = frame - intro
        let beat = ((elapsed % phrase) * beats / phrase) + 1
        let offset = (beat * phrase + beats - 1) / beats
        return (intro + (elapsed / phrase) * phrase + offset, offset % phrase)
    }
}


struct AssetSound: Sound {
    let asset: AudioAsset
    var type: SoundType = .standard
    var content: SoundContent { .asset(asset) }
    var description: String { String(describing: asset) }
}

// Tracks the requested asset (including silence); native renderers apply the returned frame plan.
struct BeaconProgression {
    struct Transition: Equatable {
        let asset: AudioAsset?
        let frame: Int64
        let phraseOffset: Int64
        let nextLoopFrame: Int64
    }

    let timing: BeaconTiming
    private var scheduled = false
    private var selected: AudioAsset?
    private(set) var finishing = false

    init(timing: BeaconTiming) { self.timing = timing }

    mutating func select(_ asset: AudioAsset?, at frame: Int64?) -> Transition? {
        guard !finishing, !scheduled || selected != asset else { return nil }
        scheduled = true
        selected = asset
        let next = timing.next(after: frame)
        return Transition(asset: asset, frame: next.start, phraseOffset: next.offset,
                          nextLoopFrame: next.start + (next.offset == 0 ? 0 : timing.phrase - next.offset))
    }

    mutating func finish(at frame: Int64?) -> Int64? {
        guard !finishing else { return nil }
        finishing = true
        return scheduled ? timing.next(after: frame).start : 0
    }
}
