//
//  POI.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import CoreLocation
import SSDataDomain
import SSGeo

typealias POI = SSDataDomain.POI
typealias SelectablePOI = SSDataDomain.SelectablePOI
typealias MatchablePOI = SSDataDomain.MatchablePOI

extension SSDataDomain.POI {
    var centroidCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centroidLatitude, longitude: centroidLongitude)
    }

    var centroidLocation: CLLocation {
        centroidSSGeoCoordinate.clLocation
    }

    func contains(location: CLLocationCoordinate2D) -> Bool {
        contains(location: location.ssGeoCoordinate)
    }

    func closestLocation(from location: CLLocation, useEntranceIfAvailable: Bool) -> CLLocation {
        closestLocation(from: location.ssGeoLocation, useEntranceIfAvailable: useEntranceIfAvailable).clLocation
    }

    func distanceToClosestLocation(from location: CLLocation, useEntranceIfAvailable: Bool) -> CLLocationDistance {
        distanceToClosestLocation(from: location.ssGeoLocation, useEntranceIfAvailable: useEntranceIfAvailable)
    }

    func bearingToClosestLocation(from location: CLLocation, useEntranceIfAvailable: Bool) -> CLLocationDirection {
        bearingToClosestLocation(from: location.ssGeoLocation, useEntranceIfAvailable: useEntranceIfAvailable)
    }
}
