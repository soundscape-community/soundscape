// Copyright (c) Soundscape Community Contributers.

import Foundation
import SSGeo

public protocol POI {
    var key: String { get }
    var name: String { get }
    var localizedName: String { get }
    var superCategory: String { get }
    var addressLine: String? { get }
    var streetName: String? { get }
    var centroidLatitude: Double { get }
    var centroidLongitude: Double { get }

    func contains(location: SSGeoCoordinate) -> Bool
    func closestLocation(from location: SSGeoLocation, useEntranceIfAvailable: Bool) -> SSGeoLocation
    func distanceToClosestLocation(from location: SSGeoLocation, useEntranceIfAvailable: Bool) -> Double
    func bearingToClosestLocation(from location: SSGeoLocation, useEntranceIfAvailable: Bool) -> Double
}

public protocol SelectablePOI: POI {
    var lastSelectedDate: Date? { get set }
}

public protocol MatchablePOI: POI {
    var matchKeys: [String] { get }
}

public extension POI {
    var centroidSSGeoCoordinate: SSGeoCoordinate {
        SSGeoCoordinate(latitude: centroidLatitude, longitude: centroidLongitude)
    }

    var centroidSSGeoLocation: SSGeoLocation {
        SSGeoLocation(coordinate: centroidSSGeoCoordinate)
    }

    func isEqual(_ poi: any POI) -> Bool {
        key == poi.key
    }
}
