//
//  GDASpatialDataResultEntity+Typeable.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

extension GDASpatialDataResultEntity: Typeable {
    
    func isOfType(_ type: PrimaryType) -> Bool {
        switch type {
        case .transit:
            return isOfType(.transitStop)
        case .food:
            return isFood()
        case .landmarks:
            return isLandmarks()
        case .park:
            return isPark()
        case .hotel:
            return isHotel()
        }
    }
    
    func isOfType(_ type: SecondaryType) -> Bool {
        switch type {
        case .transitStop:
            return isTransitStop()
        case .food:
            return isFood()
        case .landmarks:
            return isLandmarks()
        case .park:
            return isPark()
        case .hotel:
            return isHotel()
        }
    }
    
    private func isTransitStop() -> Bool {
        print("Raw superCategory: \(superCategory)")
        guard let category = SuperCategory(rawValue: superCategory) else {
            print("Failed to map superCategory to SuperCategory enum")
            return false
        }
        print("Mapped category: \(category)")
        let isTransitLocation = category == .mobility && localizedName.lowercased().contains(GDLocalizedString("osm.tag.bus_stop").lowercased())
        print("Transit location check: \(isTransitLocation)")
        if isTransitLocation {
            print("Transit location found: \(localizedName)")
        }
        return isTransitLocation
    }

    //convinence store
    private func isFood() -> Bool {
        print("Raw superCategory: \(superCategory)")
        guard let category = SuperCategory(rawValue: superCategory) else {
            print("Failed to map superCategory to SuperCategory enum")
            return false
        }
        print("Mapped category: \(category)")
        let isFoodLocation = category == .places &&
        localizedName.lowercased().contains(GDLocalizedString("osm.tag.restaurant").lowercased())
//        let osmTags = ["amenity=restaurant", "amenity=bar", "amenity=cafe", "amenity=fast_food", "amenity=ice_cream", "amenity=pub"]

        // List of restaurant-related OSM tags using localized strings
        print("Transit location check: \(isFoodLocation)")
        
        if isFoodLocation {
            print("Food location found: \(localizedName)")
        }
        
        return isFoodLocation
    }




    private func isLandmarks() -> Bool {
        guard let category = SuperCategory(rawValue: superCategory) else {
            return false
        }

        let landmarkKeywords = ["monument", "statue", "museum", "historic", "landmark", "cathedral"]

        for keyword in landmarkKeywords {
            if localizedName.lowercased().contains(keyword) {
                return true
            }
        }

        return category == .landmarks
    }
    
    private func isPark() -> Bool {
        guard let category = SuperCategory(rawValue: superCategory) else {
            return false
        }

        let parkKeywords = [
            "park", "garden", "green space", "recreation area", "playground",
            "nature reserve", "botanical garden", "public garden", "field", "reserve"
        ]
        
        // Keywords to exclude parking lots
        let excludeKeywords = [
            "parking lot", "car park", "parking", "garage", "park and ride"
        ]

        let lowercasedName = localizedName.lowercased()

        // Check if the name contains any park keyword
        var containsParkKeyword = false
        for keyword in parkKeywords {
            if lowercasedName.contains(keyword) {
                containsParkKeyword = true
                break
            }
        }
        
        // Check if the name contains any exclude keyword
        var containsExcludeKeyword = false
        for keyword in excludeKeywords {
            if lowercasedName.contains(keyword) {
                containsExcludeKeyword = true
                break
            }
        }

        return containsParkKeyword && !containsExcludeKeyword
    }


    
    private func isHotel() -> Bool {
        return false
    }
}
