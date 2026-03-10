// Copyright (c) Soundscape Community Contributers.

import Foundation
import SSGeo

public final class GenericLocation: SelectablePOI {
    public var key: String
    public var lastSelectedDate: Date?
    public var name: String
    public var localizedName: String { name }
    public var superCategory: String = SuperCategory.places.rawValue
    public var amenity: String! = "custom location"
    public var phone: String?
    public var addressLine: String?
    public var streetName: String?
    public var searchString: String?
    public var dynamicURL: String?
    public var latitude: Double
    public var longitude: Double
    public var coordinates: [Any]?
    public var entrances: [any POI]?

    public var centroidLatitude: Double {
        get { latitude }
        set { latitude = newValue }
    }

    public var centroidLongitude: Double {
        get { longitude }
        set { longitude = newValue }
    }

    public var geoCoordinate: SSGeoCoordinate {
        SSGeoCoordinate(latitude: latitude, longitude: longitude)
    }

    public var geoLocation: SSGeoLocation {
        SSGeoLocation(coordinate: geoCoordinate)
    }

    public init(ref: ReferenceEntity) {
        key = ref.id
        name = ref.nickname ?? ref.estimatedAddress ?? ""
        lastSelectedDate = ref.lastSelectedDate
        latitude = ref.latitude
        longitude = ref.longitude
        addressLine = ref.estimatedAddress
    }

    public init(lat: Double, lon: Double, name nickname: String = "", address: String? = nil) {
        key = UUID().uuidString
        name = nickname
        lastSelectedDate = Date()
        latitude = lat
        longitude = lon
        addressLine = address
    }

    public convenience init(coordinate: SSGeoCoordinate, name nickname: String = "", address: String? = nil) {
        self.init(lat: coordinate.latitude, lon: coordinate.longitude, name: nickname, address: address)
    }

    public func contains(location: SSGeoCoordinate) -> Bool {
        abs(location.latitude - latitude) <= 0.0000009 && abs(location.longitude - longitude) <= 0.0000009
    }

    public func distanceToClosestLocation(from location: SSGeoLocation, useEntranceIfAvailable: Bool) -> Double {
        SSGeoMath.distanceMeters(from: geoCoordinate, to: location.coordinate)
    }

    public func bearingToClosestLocation(from location: SSGeoLocation, useEntranceIfAvailable: Bool) -> Double {
        SSGeoMath.initialBearingDegrees(from: location.coordinate, to: geoCoordinate)
    }

    public func closestLocation(from location: SSGeoLocation, useEntranceIfAvailable: Bool) -> SSGeoLocation {
        geoLocation
    }
}
