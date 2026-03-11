//
//  LocationCallout.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import CoreLocation
import SSLanguage

struct LocationCallout: LocationCalloutProtocol {
    
    // MARK: Properties
    
    let id = UUID()
    
    let origin: CalloutOrigin
    
    let timestamp = Date()
    
    let geocoderResult: GenericGeocoderResult
    
    let includePrefixSound: Bool
    
    let useClosestRoadIfAvailable: Bool
    
    // MARK: Computed Properties
    
    var generatedAt: CLLocation {
        return geocoderResult.location
    }
    
    var includeInHistory: Bool {
        return poi != nil || road != nil
    }
    
    var debugDescription: String {
        return GDLocalizationUnnecessary("")
    }
    
    var logCategory: String {
        return "location"
    }
    
    var defaultMarkerName: String {
        if let poiComponents = geocoderResult.getPOICalloutComponents() {
            return GDLocalizedString("markers.marker_distance_from_poi", LanguageFormatter.string(from: poiComponents.distance, rounded: true), poiComponents.name)
        } else if let roadComponents = geocoderResult.getRoadCalloutComponents() {
            return GDLocalizedString("markers.marker_distance_from_poi", LanguageFormatter.string(from: roadComponents.distance, rounded: true), roadComponents.name)
        } else {
            // Create a generic name in the form: "Marker created on Feb 29, 2016 at 12:24 PM"
            let formatter = DateFormatter()
            formatter.locale = LocalizationContext.currentAppLocale
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return GDLocalizedString("markers.marker_created_on", formatter.string(from: Date()))
        }
    }
    
    var poi: POI? {
        return geocoderResult.poi
    }
    
    var road: Road? {
        return geocoderResult.road
    }
    
    init(_ calloutOrigin: CalloutOrigin, geocodedResult: GenericGeocoderResult, sound playCategorySound: Bool = false, useClosest: Bool = false) {
        self.origin = calloutOrigin
        self.geocoderResult = geocodedResult
        self.includePrefixSound = playCategorySound
        self.useClosestRoadIfAvailable = useClosest
    }
    
    func sounds(for location: CLLocation?, isRepeat: Bool, automotive: Bool = false) -> Sounds {
        var sounds: [Sound] = []
        
        // If we aren't playing the mode enter/exit sounds, play the category sound instead
        if includePrefixSound {
            sounds.append(GlyphSound(.locationSense, direction: .ahead))
        }
        
        if !isRepeat {
            let roadComponents = geocoderResult.getRoadCalloutComponents(fromLocation: location, useClosest: useClosestRoadIfAvailable)
            let poiComponents = geocoderResult.getPOICalloutComponents(fromLocation: location)
            
            // Create the localization string key
            if let direction = geocoderResult.heading.value {
                let cardinal = CardinalDirection(direction: direction)!
                let style: LanguageFormatter.CardinalMovementStyle = if geocoderResult.heading.isCourse {
                    automotive ? .traveling : .heading
                } else {
                    .facing
                }
                let string = LanguageFormatter.cardinalMovementString(
                    direction: cardinal,
                    style: style
                )
            
                sounds.append(TTSSound(string, compass: direction))
            
                if let roadComponents = roadComponents {
                    let string = LanguageFormatter.namedLocationString(
                        kind: .nearestRoad,
                        name: roadComponents.name,
                        style: .current(
                            distance: roadComponents.formattedDistance,
                            direction: roadComponents.encodedDirection
                        )
                    )
                    sounds.append(TTSSound(string, at: roadComponents.location))
                }
            
                if let poiComponents = poiComponents {
                    let string = LanguageFormatter.namedLocationString(
                        kind: .pointOfInterest,
                        name: poiComponents.name,
                        style: .current(
                            distance: poiComponents.formattedDistance,
                            direction: poiComponents.encodedDirection
                        )
                    )
                    sounds.append(TTSSound(string, at: poiComponents.location))
                }
            } else {
                if roadComponents == nil && poiComponents == nil {
                    let string = GDLocalizedString("general.error.heading")
                    sounds.append(TTSSound(string, direction: .ahead))
                } else {
                    if let roadComponents = roadComponents {
                        let string = LanguageFormatter.namedLocationString(
                            kind: .nearestRoad,
                            name: roadComponents.name,
                            style: .current(distance: roadComponents.formattedDistance, direction: nil)
                        )
                        sounds.append(TTSSound(string, direction: .ahead))
                    }
                    
                    if let poiComponents = poiComponents {
                        let string = LanguageFormatter.namedLocationString(
                            kind: .pointOfInterest,
                            name: poiComponents.name,
                            style: .current(distance: poiComponents.formattedDistance, direction: nil)
                        )
                        sounds.append(TTSSound(string, direction: .ahead))
                    }
                }
            }
        } else {
            sounds.append(TTSSound(GDLocalizedString("directions.previous_location"), direction: .ahead))
            
            if let roadComponents = geocoderResult.getRoadCalloutComponents(useClosest: useClosestRoadIfAvailable, useOriginalHeading: true) {
                let string = LanguageFormatter.namedLocationString(
                    kind: .nearestRoad,
                    name: roadComponents.name,
                    style: .previous(
                        distance: roadComponents.formattedDistance,
                        direction: roadComponents.encodedDirection
                    )
                )
                sounds.append(TTSSound(string, at: roadComponents.location))
            }
            
            if let poiComponents = geocoderResult.getPOICalloutComponents(useOriginalHeading: true) {
                let string = LanguageFormatter.namedLocationString(
                    kind: .pointOfInterest,
                    name: poiComponents.name,
                    style: .previous(
                        distance: poiComponents.formattedDistance,
                        direction: poiComponents.encodedDirection
                    )
                )
                sounds.append(TTSSound(string, at: poiComponents.location))
            }
        }
        
        return Sounds(sounds)
    }
    
    func moreInfoDescription(for location: CLLocation?) -> String {
        guard let locationDescription = distanceDescription(for: location, tts: true) else {
            return GDLocalizedString("previous_location.announced_name", timeDescription)
        }
        
        return GDLocalizedString("previous_location.announced_name_distance", timeDescription, locationDescription)
    }
}
