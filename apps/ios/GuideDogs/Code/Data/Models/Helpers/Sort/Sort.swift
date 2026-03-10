//
//  Sort.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import SSDataDomain

typealias Sort = SSDataDomain.Sort

extension SSDataDomain.Sort {
    static func distance(origin: CLLocation, useEntranceIfAvailable: Bool = false) -> any SortPredicate {
        SSDataDomain.Sort.distance(origin: origin.ssGeoLocation, useEntranceIfAvailable: useEntranceIfAvailable)
    }
}
