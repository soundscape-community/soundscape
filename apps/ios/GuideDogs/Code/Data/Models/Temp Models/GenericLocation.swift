//
//  GenericLocation.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import SSDataDomain
import SSGeo

typealias GenericLocation = SSDataDomain.GenericLocation

extension SSDataDomain.GenericLocation {
    var location: CLLocation {
        geoCoordinate.clLocation
    }
}
