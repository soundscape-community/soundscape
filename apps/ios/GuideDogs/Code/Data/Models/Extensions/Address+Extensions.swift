//
//  Address+Extensions.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import SSGeo

extension Address: SelectablePOI {
    
    var localizedName: String {
        return name
    }
    
    var superCategory: String {
        return SuperCategory.places.rawValue
    }
    
    var location: CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }

    var geoCoordinate: SSGeoCoordinate {
        SSGeoCoordinate(latitude: latitude, longitude: longitude)
    }
    
    var coordinates: [Any]? {
        return nil
    }
    
    var entrances: [POI]? {
        return nil
    }
    
    func contains(location: SSGeoCoordinate) -> Bool {
        latitude == location.latitude && longitude == location.longitude
    }
    
    func updateDistanceAndBearing(with location: CLLocation) {
        assert(false, "`updateDistanceAndBearing(with location:)` is missing implementation")
        
        // no-op
        return
    }
    
    func distanceToClosestLocation(from location: SSGeoLocation, useEntranceIfAvailable: Bool) -> Double {
        SSGeoMath.distanceMeters(from: geoCoordinate, to: location.coordinate)
    }
    
    func bearingToClosestLocation(from location: SSGeoLocation, useEntranceIfAvailable: Bool) -> Double {
        SSGeoMath.initialBearingDegrees(from: location.coordinate, to: geoCoordinate)
    }
    
    func closestLocation(from location: SSGeoLocation, useEntranceIfAvailable: Bool) -> SSGeoLocation {
        SSGeoLocation(coordinate: geoCoordinate)
    }
    
}

extension Address {
    
    @MainActor
    static func addressContainsStreet(address: String, streetName: String) -> Bool {
        let addressNorm = LanguageFormatter.expandCodedDirection(for: address).lowercasedWithAppLocale()
        let streetNameNorm = PostalAbbreviations.format(streetName, locale: LocalizationContext.currentAppLocale).lowercasedWithAppLocale()

        return addressNorm.contains(streetNameNorm)
    }
    
}
