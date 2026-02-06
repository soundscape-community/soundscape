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
    
    func contains(location: CLLocationCoordinate2D) -> Bool {
        return self.location.coordinate.latitude == location.latitude && self.location.coordinate.longitude == location.longitude
    }
    
    func updateDistanceAndBearing(with location: CLLocation) {
        assert(false, "`updateDistanceAndBearing(with location:)` is missing implementation")
        
        // no-op
        return
    }
    
    func distanceToClosestLocation(from location: CLLocation, useEntranceIfAvailable: Bool) -> CLLocationDistance {
        return SSGeoMath.distanceMeters(from: geoCoordinate, to: location.coordinate.ssGeoCoordinate)
    }
    
    func bearingToClosestLocation(from location: CLLocation, useEntranceIfAvailable: Bool) -> CLLocationDirection {
        return SSGeoMath.initialBearingDegrees(from: location.coordinate.ssGeoCoordinate, to: geoCoordinate)
    }
    
    func closestLocation(from location: CLLocation, useEntranceIfAvailable: Bool) -> CLLocation {
        return geoCoordinate.clLocation
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
