//
//  LocationCalloutProtocol.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import CoreLocation
import SSGeo

protocol LocationCalloutProtocol: CalloutProtocol {
    var generatedAt: CLLocation { get }
    
    var defaultMarkerName: String { get }
}

@MainActor
extension LocationCalloutProtocol {
    var prefixSound: Sound? {
        return GlyphSound(.locationSense)
    }
    
    func distanceDescription(for location: CLLocation?, tts: Bool = false) -> String? {
        guard let location = location else {
            return nil
        }
        
        let distance = location.coordinate.ssGeoCoordinate.distance(to: generatedAt.coordinate.ssGeoCoordinate)
        
        if tts {
            return LanguageFormatter.spellOutDistance(distance)
        }
        
        return LanguageFormatter.string(from: distance)
    }
}
