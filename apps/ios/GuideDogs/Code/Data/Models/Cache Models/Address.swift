//
//  Address.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import RealmSwift

class Address: Object {
    
    // MARK: Realm Properties
    
    @Persisted(primaryKey: true) var key: String = UUID().uuidString
    @Persisted var lastSelectedDate: Date?
    @Persisted var name: String = ""
    @Persisted var addressLine: String?
    @Persisted var streetName: String?
    @Persisted var latitude: CLLocationDegrees = 0.0
    @Persisted var longitude: CLLocationDegrees = 0.0
    @Persisted var centroidLatitude: CLLocationDegrees = 0.0
    @Persisted var centroidLongitude: CLLocationDegrees = 0.0
    @Persisted var searchString: String?
    
    // MARK: Initialization
    
    convenience init(geocodedAddress: GeocodedAddress, searchString: String? = nil) {
        self.init()
        
        name = geocodedAddress.name
        addressLine = geocodedAddress.addressLine
        streetName = geocodedAddress.streetName
        latitude = geocodedAddress.location.coordinate.latitude
        longitude = geocodedAddress.location.coordinate.longitude
        centroidLatitude = geocodedAddress.location.coordinate.latitude
        centroidLongitude = geocodedAddress.location.coordinate.longitude
        self.searchString = searchString
    }
}
