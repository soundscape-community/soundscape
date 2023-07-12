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
/// To add one, be sure that its URL schemes if any are added to Info.plist,
/// then add to the enum and the switches below
/// "deeplinks" are different than URL schemes; deeplinks can be arbitrary domains
/// and will usually fall back to a web version if the corresponding app isn't installed, while URL schemes tend to be less cross-platform and need to be manually added in Info.plist.
enum ExternalNavigationApps: String, CaseIterable{
    case appleMaps
    case googleMaps
    case waze

    /// Should return a localized title for each supported app
    var localizedTitle: String {
        switch self {
        case .googleMaps: return "Google Maps"
            case .waze: return "Waze"
            case .appleMaps: return "Apple Maps"
        }
    }
    func url(location: CLLocation) -> URL? {
        // Zoom level for all supported map apps and sites
        let zoom = 10
        switch self {
            case .appleMaps: return URL(string: "https://maps.apple.com/?sll=\(location.coordinate.latitude),\(location.coordinate.longitude)&z=\(zoom)&t=s")
            case .googleMaps: return URL(string: "https://www.google.com/maps/search/?api=1&query=\(location.coordinate.latitude)%2C\(location.coordinate.longitude)")
            case .waze: return URL(string: "https://www.waze.com/ul?ll=\(location.coordinate.latitude)%2C\(location.coordinate.longitude)&navigate=yes&zoom=\(zoom)")

        }
    }
}
