//
//  SecondaryRoadsContext.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import SwiftUI

/// Represents secondary road types.
///
/// In road or intersection detection logic, this is be used to determine how to handle secondary roads,
/// such as to include or exclude specific types, like service roads or walking paths.
enum SecondaryRoadsContext {
    /// Represents the default secondary road types, such as walking paths.
    case standard
    
    /// Represents secondary road types applicable in an automotive state, such as walking paths and service roads.
    case automotive
    
    /// Represents all the secondary road types which are unnamed, such as walking paths, service roads and residential streets.
    case strict
}

extension SecondaryRoadsContext {
    
    private static var standardSecondaryRoadTypes = ["walking_path",
                                                     "bicycle_path",
                                                     "crossing",
                                                     "steps",
                                                     "merging_lane"]
    
    private static var automotiveSecondaryRoadTypes = standardSecondaryRoadTypes + ["road",
                                                                                    "service_road"]
    
    private static var strictSecondaryRoadTypes = automotiveSecondaryRoadTypes + ["residential_street",
                                                                                  "pedestrian_street"]
    
    /// A list of road types openscape considers secondary, depending on the context.
    var secondaryRoadTypes: [String] {
        switch self {
        case .standard:
            return SecondaryRoadsContext.standardSecondaryRoadTypes
        case .automotive:
            return SecondaryRoadsContext.automotiveSecondaryRoadTypes
        case .strict:
            return SecondaryRoadsContext.strictSecondaryRoadTypes
        }
    }
    
    /// A list of localized road names openscape considers secondary, depending on the context.
    var localizedSecondaryRoadNames: [String] {
        // Type -> localization key -> localized string
        // "walking_path" -> "osm.tag.walking_path" -> "Walking Path" (en-US)
        return secondaryRoadTypes.map { GDLocalizedString("osm.tag.\($0)") }
    }
    
}

@MainActor
enum SpatialSearchBootstrap {
    static func configureDefaults() {
        RealmSpatialSearchBootstrap.configureDefaults()
    }
}

@MainActor
enum ReverseGeocoderLookup {
    static func road(by key: String?) -> Road? {
        RealmReverseGeocoderLookup.road(by: key)
    }

    static func poi(by key: String?) -> POI? {
        RealmReverseGeocoderLookup.poi(by: key)
    }

    static func intersection(by key: String?) -> Intersection? {
        RealmReverseGeocoderLookup.intersection(by: key)
    }

    static func fetchEstimatedAddress(for location: CLLocation, completion: @escaping (GeocodedAddress?) -> Void) {
        RealmReverseGeocoderLookup.fetchEstimatedAddress(for: location, completion: completion)
    }
}

@MainActor
enum SpatialPreviewSamples {
    static func bootstrap() {
        RealmSampleDataBootstrap.bootstrap()
    }

    static func markerIDs() -> [String] {
        RealmReferenceEntity.samples.map(\.id)
    }

    static func sampleMarkerID() -> String {
        RealmReferenceEntity.sample.id
    }

    static func secondarySampleMarkerID() -> String {
        RealmReferenceEntity.sample3.id
    }
}

@MainActor
enum SpatialPreviewEnvironment {
    static func configure<Content: View>(_ view: Content) -> some View {
        RealmPreviewEnvironment.configure(view)
    }
}
