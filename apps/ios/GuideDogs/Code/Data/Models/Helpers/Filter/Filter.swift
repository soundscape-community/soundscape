//
//  Filter.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import SSDataDomain

typealias Filter = SSDataDomain.Filter

extension SSDataDomain.Filter {
    static func location(expected: CLLocation) -> any FilterPredicate {
        SSDataDomain.Filter.location(expected: expected.ssGeoLocation)
    }
}
