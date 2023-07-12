//
//  ExternalNavigationApps.swift
//  Openscape
//
//  Created by Blake Oliver on 7/11/23.
//  Copyright © 2023 Openscape community. All rights reserved.
//

import Foundation
import CoreLocation

/// The external map / direction apps we support opening a single destination in
enum ExternalNavigationApps: String, CaseIterable{
    //case googleMaps
    //case waze
    case appleMaps

    /// Should return a localized title for each supported app
    var localizedTitle: String {
        switch self {
            //case .googleMaps: return "Google Maps"
            //case .waze: return "Waze"
            case .appleMaps: return "Apple Maps"
        }
    }
    func url(location: CLLocation) -> URL? {
        switch self {
            case .appleMaps: return URL(string: "https://maps.apple.com/?sll=\(location.coordinate.latitude),\(location.coordinate.longitude)&z=10&t=s")
        }
    }
}
