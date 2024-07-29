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
            return false
        }
        print("Mapped category: \(category)")
        let isTransitLocation = category == .mobility && localizedName.lowercased().contains(GDLocalizedString("osm.tag.bus_stop").lowercased())

        return isTransitLocation
    }

    //convinence store
    private func isFood() -> Bool {
        
        guard let category = SuperCategory(rawValue: superCategory) else {
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
            GDLocalizedString("osm.tag.cathedral")
        ]

        let lowercasedAmenity = amenity.lowercased()

        let isLandmarkLocation = landmarkTags.contains(lowercasedAmenity)

        return isLandmarkLocation 
    }

    
    private func isPark() -> Bool {
            guard let category = SuperCategory(rawValue: superCategory) else {
                print("Failed to map superCategory to SuperCategory enum")
                return false
            }

            // OSM tags related to parks and green spaces in English
            let parkTags = [
                "park", "garden", "green_space", "recreation_area", "playground",
                "nature_reserve", "botanical_garden", "public_garden", "field", "reserve"
            ]

        let lowercasedAmenity = amenity.lowercased()

            let isParkLocation = category == .places && parkTags.contains { tag in tag == lowercasedAmenity }
            print("Place name: \(localizedName)")
            print("Park location check: \(isParkLocation)")
            print("Raw superCategory: \(superCategory)")
            print("Mapped category: \(category)")
            return isParkLocation

    }



    
    private func isHotel() -> Bool {
        return false
    }
}
