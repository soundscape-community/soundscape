//
//  Address.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation

final class Address {
    
    // MARK: Properties
    
    var key: String = UUID().uuidString
    var lastSelectedDate: Date?
    var name: String = ""
    var addressLine: String?
    var streetName: String?
    var latitude: CLLocationDegrees = 0.0
    var longitude: CLLocationDegrees = 0.0
    var centroidLatitude: CLLocationDegrees = 0.0
    var centroidLongitude: CLLocationDegrees = 0.0
    var searchString: String?
    
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
