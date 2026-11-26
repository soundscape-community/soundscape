//
//  SoundType.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation

struct AudioCoordinate: Sendable {
    let latitude: Double
    let longitude: Double

    func bearing(to other: Self) -> Double {
        let start = latitude * .pi / 180
        let end = other.latitude * .pi / 180
        let delta = (other.longitude - longitude) * .pi / 180
        return atan2(sin(delta) * cos(end), cos(start) * sin(end) - sin(start) * cos(end) * cos(delta)) * 180 / .pi
    }

    func distance(from other: Self) -> Double {
        let lat = (other.latitude - latitude) * .pi / 360
        let lon = (other.longitude - longitude) * .pi / 360
        let h = sin(lat) * sin(lat) + cos(latitude * .pi / 180) * cos(other.latitude * .pi / 180) * sin(lon) * sin(lon)
        return 12_742_000 * asin(sqrt(min(1, max(0, h))))
    }
}

enum SoundDistanceRenderingStyle: String, Sendable {
    case ring
    case real
}

enum SoundType: Sendable {
    case standard
    case localized(AudioCoordinate, SoundDistanceRenderingStyle)
    case relative(Double, SoundDistanceRenderingStyle)
    case compass(Double, SoundDistanceRenderingStyle)

    func position(listener: AudioCoordinate?, heading: Double, ring: Double) -> (bearing: Double, distance: Double)? {
        switch self {
        case .standard: return nil
        case .relative(let direction, _): return (heading + direction, ring)
        case .compass(let direction, _): return (direction, ring)
        case .localized(let point, let style):
            guard let listener else { return nil }
            return (listener.bearing(to: point), style == .ring ? ring : listener.distance(from: point))
        }
    }
}
