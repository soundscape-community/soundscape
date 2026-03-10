//
//  BeaconDetailLabel.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import SSGeo

@MainActor
enum BeaconDetailRuntime {
    static func isUserWithinDestinationGeofence(_ userLocation: SSGeoLocation) -> Bool {
        UIRuntimeProviderRegistry.providers.beaconDetailIsUserWithinDestinationGeofence(userLocation)
    }
}

@MainActor
struct BeaconDetailLocalizedLabel {
    
    // MARK: Properties
    
    let detail: BeaconDetail
    
    private var formatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.second, .minute]
        formatter.maximumUnitCount = 0
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }
    
    private var accessibilityFormatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.second, .minute, .hour]
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .full
        return formatter
    }
    
    // MARK: `LocalizedLabel`
    
    var title: LocalizedLabel {
        var text: String
        var accessibilityText: String?
        
        if let routeDetail = detail.routeDetail {
            let name = routeDetail.displayName
            let count = String(routeDetail.waypoints.count)
            
            if let route = routeDetail.guidance, let index = route.currentWaypoint?.index {
                let indexStr = String(index + 1)
                
                text = GDLocalizedString("route.title", name, indexStr, count)
                accessibilityText = GDLocalizedString("route.title.accessibility_label", name, indexStr, count)
            } else {
                text = name
            }
        } else {
            text = GDLocalizedString("beacon.audio_beacon")
        }
        
        return LocalizedLabel(text: text, accessibilityText: accessibilityText)
    }
    
    var time: LocalizedLabel? {
        guard let routeDetail = detail.routeDetail else {
            return nil
        }
        
        return routeDetail.labels.time
    }
    
    var name: LocalizedLabel {
        let text = detail.locationDetail.displayName
        let accessibilityText = GDLocalizedString("beacon.beacon_on", text)
        
        return LocalizedLabel(text: text, accessibilityText: accessibilityText)
    }
    
    func distance(from userLocation: SSGeoLocation?) -> LocalizedLabel {
        var text: String
        var accessibilityText: String?
        
        if let userLocation = userLocation, BeaconDetailRuntime.isUserWithinDestinationGeofence(userLocation) {
            text = GDLocalizedString("poi_screen.section_header.nearby")
        } else if let dLabel = detail.locationDetail.labels.distance(from: userLocation) {
            text = dLabel.text
            accessibilityText = dLabel.accessibilityText
        } else {
            text = GDLocalizedString("beacon.distance.unknown")
        }
        
        return LocalizedLabel(text: text, accessibilityText: accessibilityText)
    }
    
    func moreInformation(userLocation: SSGeoLocation?) -> LocalizedLabel {
        var text: String
        var accessibilityText: String?
            
        if let userLocation = userLocation, BeaconDetailRuntime.isUserWithinDestinationGeofence(userLocation) {
            // "<Some Place> is nearby. Street address is <Some Address>"
            text = LanguageFormatter.namedLocationStreetAddressString(
                name: detail.locationDetail.displayName,
                address: detail.locationDetail.displayAddress,
                style: .nearby
            )
        } else if let dLabel = detail.locationDetail.labels.distance(from: userLocation) {
            // "<Some Place> is currently <5 meters>. Street address is <Some Address>"
            text = LanguageFormatter.namedLocationStreetAddressString(
                name: detail.locationDetail.displayName,
                address: detail.locationDetail.displayAddress,
                style: .current(distance: dLabel.text)
            )
            accessibilityText = LanguageFormatter.namedLocationStreetAddressString(
                name: detail.locationDetail.displayName,
                address: detail.locationDetail.displayAddress,
                style: .current(distance: dLabel.accessibilityText ?? dLabel.text)
            )
        } else {
            // "<Some Place>. Street address is <Some Address>. Distance unknown."
            text = LanguageFormatter.namedLocationStreetAddressString(
                name: detail.locationDetail.displayName,
                address: detail.locationDetail.displayAddress,
                style: .unknownDistance
            )
        }
            
        return LocalizedLabel(text: text, accessibilityText: accessibilityText)
    }
    
}

extension BeaconDetail {
    
    var labels: BeaconDetailLocalizedLabel {
        return BeaconDetailLocalizedLabel(detail: self)
    }
    
}
