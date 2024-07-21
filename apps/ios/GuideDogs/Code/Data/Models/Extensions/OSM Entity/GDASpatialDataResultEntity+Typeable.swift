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
        case .business:
            return isBusiness()
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
        case .business:
            return isBusiness()
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
        guard let category = SuperCategory(rawValue: superCategory) else {
            return false
        }

        // Expanded keywords or patterns to identify food-related places
        let foodKeywords = [
            "restaurant", "cafe", "bistro", "diner", "eatery",
            "bakery", "pub", "bar", "coffee", "tea",
            "fast food", "food truck", "pizzeria",
            "buffet", "deli"
        ]

        for keyword in foodKeywords {
            if localizedName.lowercased().contains(keyword) {
                return true
            }
        }

        return category == .food
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
    
    private func isBusiness() -> Bool {
        return false
    }
    
    private func isHotel() -> Bool {
        return false
    }
}
