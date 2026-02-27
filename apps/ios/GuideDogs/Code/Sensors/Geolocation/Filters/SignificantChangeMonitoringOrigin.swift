//
//  SignificantChangeMonitoringOrigin.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import SSGeo

@MainActor
class SignificantChangeMonitoringOrigin {

    struct POIIntegration {
        let poisNear: (CLLocation, CLLocationDistance) -> [POI]?

        static let disabled = POIIntegration(poisNear: { _, _ in nil })
    }
    
    // MARK: Properties

    private static var poiIntegration: POIIntegration = .disabled
    
    let poi: POI?
    let location: CLLocation?

    static func configure(with poiIntegration: POIIntegration) {
        self.poiIntegration = poiIntegration
    }

    static func resetForTesting() {
        poiIntegration = .disabled
    }
    
    // MARK: Initialization
    
    init(_ location: CLLocation) {
        let pois = Self.poiIntegration.poisNear(location, 50.0)
        let poi = pois?.first(where: { $0.contains(location: location.coordinate) })
        
        if let poi = poi {
            // If the user is inside a POI, set the origin to the building and resume
            // normal operation when the user leaves the POI
            self.poi = poi
            self.location = nil
        } else {
            // Resume normal operation when the user has moved a significant distance
            // from the current location
            self.poi = nil
            self.location = location
        }
    }
    
    // MARK: Location Updates
    
    func shouldUpdateLocation(_ location: CLLocation) -> Bool {
        if let origin = self.poi {
            // Update the user's location after the user has left the
            // given POI
            return origin.contains(location: location.coordinate) == false
        } else if let origin = self.location {
            // Update the user's location after the user has moved
            // more than 40 meters
            return location.coordinate.ssGeoCoordinate.distance(to: origin.coordinate.ssGeoCoordinate) > 40.0
        }
        
        // `origin` is invalid
        return false
    }
    
}

extension SignificantChangeMonitoringOrigin: Equatable {
    
    static func == (lhs: SignificantChangeMonitoringOrigin, rhs: SignificantChangeMonitoringOrigin) -> Bool {
        if let poiA = lhs.poi, let poiB = lhs.poi {
            return poiA.isEqual(poiB)
        }
        
        if let locationA = lhs.location, let locationB = lhs.location {
            return locationA == locationB
        }
        
        return false
    }
    
}
