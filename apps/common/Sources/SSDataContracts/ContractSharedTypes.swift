// Copyright (c) Soundscape Community Contributers.

import Foundation
import SSGeo

public struct SpatialIntersectionRegion: Sendable {
    public let center: SSGeoCoordinate
    public let latitudeDelta: Double
    public let longitudeDelta: Double

    public init(center: SSGeoCoordinate, latitudeDelta: Double, longitudeDelta: Double) {
        self.center = center
        self.latitudeDelta = latitudeDelta
        self.longitudeDelta = longitudeDelta
    }
}

public struct RouteReadMetadata: Sendable {
    public let id: String
    public let lastUpdatedDate: Date?

    public init(id: String, lastUpdatedDate: Date?) {
        self.id = id
        self.lastUpdatedDate = lastUpdatedDate
    }
}

public struct ReferenceReadMetadata: Sendable {
    public let id: String
    public let lastUpdatedDate: Date?

    public init(id: String, lastUpdatedDate: Date?) {
        self.id = id
        self.lastUpdatedDate = lastUpdatedDate
    }
}

public struct ReferenceCalloutReadData: Sendable {
    public let name: String
    public let superCategory: String

    public init(name: String, superCategory: String) {
        self.name = name
        self.superCategory = superCategory
    }
}

public struct EstimatedAddressReadData: Sendable {
    public let addressLine: String?
    public let streetName: String?
    public let subThoroughfare: String?

    public init(addressLine: String?, streetName: String?, subThoroughfare: String?) {
        self.addressLine = addressLine
        self.streetName = streetName
        self.subThoroughfare = subThoroughfare
    }
}

public struct AddressCacheRecord: Sendable {
    public let key: String
    public let lastSelectedDate: Date?
    public let name: String
    public let addressLine: String?
    public let streetName: String?
    public let latitude: Double
    public let longitude: Double
    public let centroidLatitude: Double
    public let centroidLongitude: Double
    public let searchString: String?

    public init(
        key: String,
        lastSelectedDate: Date?,
        name: String,
        addressLine: String?,
        streetName: String?,
        latitude: Double,
        longitude: Double,
        centroidLatitude: Double,
        centroidLongitude: Double,
        searchString: String?
    ) {
        self.key = key
        self.lastSelectedDate = lastSelectedDate
        self.name = name
        self.addressLine = addressLine
        self.streetName = streetName
        self.latitude = latitude
        self.longitude = longitude
        self.centroidLatitude = centroidLatitude
        self.centroidLongitude = centroidLongitude
        self.searchString = searchString
    }
}
