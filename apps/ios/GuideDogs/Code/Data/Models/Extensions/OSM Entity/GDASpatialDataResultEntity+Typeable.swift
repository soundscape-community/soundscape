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
        
        let restaurantTags = [
            GDLocalizedString("osm.tag.restaurant"),
            GDLocalizedString("osm.tag.fast_food"),
            GDLocalizedString("osm.tag.cafe"),
            GDLocalizedString("osm.tag.bar"),
            GDLocalizedString("osm.tag.ice_cream"),
            GDLocalizedString("osm.tag.pub"),
            GDLocalizedString("osm.tag.coffee_shop")
            
        ]
        
        let isRestaurantLocation = category == .places && restaurantTags.contains(amenity)
        
        print("Place name: \(localizedName)")
        print("Restaurant location check: \(isRestaurantLocation)")
        
        if isRestaurantLocation {
            print("Restaurant location found with amenity: \(amenity)")
        }
        
        return isRestaurantLocation
    }

    private func isLandmarks() -> Bool {
        guard let category = SuperCategory(rawValue: superCategory) else {
            return false
        }

        let landmarkTags = [
            GDLocalizedString("osm.tag.monument"),
            GDLocalizedString("osm.tag.statue"),
            GDLocalizedString("osm.tag.museum"),
            GDLocalizedString("osm.tag.historic"),
            GDLocalizedString("osm.tag.landmark"),
            GDLocalizedString("osm.tag.cathedral")
        ]

        let lowercasedAmenity = amenity.lowercased()

        let isLandmarkLocation = landmarkTags.contains(lowercasedAmenity)

        // Print the debug statements
        print("Place name: \(localizedName)")
        print("Landmark location check: \(isLandmarkLocation)")
        print("Raw superCategory: \(superCategory)")
        print("Mapped category: \(category)")

        return isLandmarkLocation || category == .landmarks
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
