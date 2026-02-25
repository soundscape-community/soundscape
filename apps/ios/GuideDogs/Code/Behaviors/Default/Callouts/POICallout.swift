//
//  POICallout.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import CoreLocation
import SSGeo

struct POICallout: POICalloutProtocol {
    let id = UUID()
    let origin: CalloutOrigin
    let timestamp = Date()
    
    let includeInHistory = true
    
    var debugDescription: String {
        if let marker = marker {
            if marker.name.isEmpty {
                // Use a default name
                return GDLocalizedString("markers.generic_name")
            } else {
                let containsMarkerInName = marker.name.lowercasedWithAppLocale().contains(GDLocalizedString("markers.generic_name").lowercasedWithAppLocale())
                
                if containsMarkerInName || marker.isTemp {
                    return marker.name
                } else {
                    return GDLocalizedString("markers.marker_with_name", marker.name)
                }
            }
        } else if let poi = poi {
            if poi.localizedName.isEmpty {
                // Use a default name
                return GDLocalizedString("location")
            } else {
                return poi.localizedName
            }
        }
        
        return ""
    }
    
    var logCategory: String {
        if let superCategory = poi?.superCategory {
            return "poi.\(superCategory)"
        }
        return "poi"
    }
    
    /// Primary key for the POI this callout refers to
    let key: String
    
    /// The user's location. If this is provided, the callout will include distance information.
    let location: CLLocation?
    
    let includeDistance: Bool
    
    let includePrefixSound: Bool
    
    let storedPOI: POI
    let storedMarker: ReferenceEntity?
    
    /// Pre-resolved POI context captured when the callout is created.
    var poi: POI? {
        storedPOI
    }
    
    var marker: ReferenceEntity? {
        storedMarker
    }
    
    /// Constructor for the POI callout with pre-resolved POI context.
    ///
    /// - Parameters:
    ///   - calloutOrigin: Origin of the callout
    ///   - poi: The POI to callout
    ///   - marker: Optional marker metadata for marker-backed POIs
    ///   - location: Location of the user when the callout was generated
    ///   - includeDistance: True if the callout should include distance information
    ///   - includePrefixSound: True if the callout should include a prefix sound
    init(_ calloutOrigin: CalloutOrigin, poi: POI, marker: ReferenceEntity? = nil, location: CLLocation? = nil, includeDistance: Bool = false, includePrefixSound: Bool = true) {
        self.origin = calloutOrigin
        self.storedPOI = poi
        self.storedMarker = marker
        self.key = poi.key
        self.location = location
        self.includeDistance = includeDistance
        self.includePrefixSound = includePrefixSound
    }
    
    /// Sounds to callout
    func sounds(for location: CLLocation?, isRepeat: Bool, automotive: Bool = false) -> Sounds {
        guard let location = location ?? self.location, let poi = poi else {
            return Sounds.empty
        }
        
        let distance: CLLocationDistance
        let name: String
        let category: SuperCategory
        let soundLocation: CLLocation
        
        if let marker = marker {
            soundLocation = marker.closestLocation(from: location)
            distance = soundLocation.coordinate.ssGeoCoordinate.distance(to: location.coordinate.ssGeoCoordinate)
            category = SuperCategory(rawValue: marker.getPOI().superCategory) ?? .undefined
            
            if marker.name.isEmpty {
                // Use a default name
                name = GDLocalizedString("markers.generic_name")
            } else {
                let containsMarkerInName = marker.name.lowercasedWithAppLocale().contains(GDLocalizedString("markers.generic_name").lowercasedWithAppLocale())
                
                if containsMarkerInName || marker.isTemp {
                    name = marker.name
                } else {
                    name = GDLocalizedString("markers.marker_with_name", marker.name)
                }
            }
        } else {
            soundLocation = poi.closestLocation(from: location)
            distance = soundLocation.coordinate.ssGeoCoordinate.distance(to: location.coordinate.ssGeoCoordinate)
            
            if poi.localizedName.isEmpty {
                // Use a default name
                name = GDLocalizedString("location")
            } else {
                name = poi.localizedName
            }
            
            category = SuperCategory(rawValue: poi.superCategory) ?? .undefined
        }
        
        var sounds = [Sound]()
        
        if includePrefixSound {
            sounds.append(GlyphSound(category.glyph, at: soundLocation))
        }
        
        if !includeDistance && !isRepeat { // Auto-Callouts
            if poi.contains(location: location.coordinate) {
                sounds.append(TTSSound(GDLocalizedString("directions.at_poi", name), at: soundLocation))
            } else {
                sounds.append(TTSSound(name, at: soundLocation))
            }
        } else { // Explore and Orient
            let formattedName = LanguageFormatter.string(from: distance, accuracy: location.horizontalAccuracy, name: name)
            sounds.append(TTSSound(formattedName, at: soundLocation))
        }
        
        // Announce "NaviLens available" for NaviLens-enabled locations,
        // unless NaviLens is already in the name
        if poi.superCategory == "navilens" && !name.lowercased().contains("navilens") {
            sounds.append(TTSSound(GDLocalizedString("directions.navilens_available"), at: soundLocation))
        }
        
        if let annotation = marker?.annotation, annotation.isEmpty == false {
            sounds.append(TTSSound(annotation, at: soundLocation))
        }
        
        return Sounds(sounds)
    }
    
    func moreInfoDescription(for location: CLLocation?) -> String {
        guard let locationDescription = distanceDescription(for: location, tts: true) else {
            return GDLocalizedString("announced_name.named", origin.localizedStringForAccessibility, timeDescription)
        }
        
        return GDLocalizedString("announced_name_distance_away.named", origin.localizedStringForAccessibility, timeDescription, locationDescription)
    }
}
