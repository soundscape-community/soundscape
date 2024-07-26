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
            GDLocalizedString("osm.tag.cathedral")
        ]

        let lowercasedAmenity = amenity.lowercased()

        let isLandmarkLocation = landmarkTags.contains(lowercasedAmenity)

        // Print the debug statements
        print("Place name: \(localizedName)")
        print("Landmark location check: \(isLandmarkLocation)")
        print("Raw superCategory: \(superCategory)")
        print("Mapped category: \(category)")

        return isLandmarkLocation 
    }

    
    private func isPark() -> Bool {
        guard let category = SuperCategory(rawValue: superCategory) else {
            return false
        }

        // OSM tags related to parks and green spaces
        let parkTags = [
            GDLocalizedString("osm.tag.park"),
            GDLocalizedString("osm.tag.garden"),
            GDLocalizedString("osm.tag.green_space"),
            GDLocalizedString("osm.tag.recreation_area"),
            GDLocalizedString("osm.tag.playground"),
            GDLocalizedString("osm.tag.nature_reserve"),
            GDLocalizedString("osm.tag.botanical_garden"),
            GDLocalizedString("osm.tag.public_garden"),
            GDLocalizedString("osm.tag.field"),
            GDLocalizedString("osm.tag.reserve")
        ]

        let lowercasedAmenity = amenity.lowercased()

        let isParkLocation = parkTags.contains(lowercasedAmenity)

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
