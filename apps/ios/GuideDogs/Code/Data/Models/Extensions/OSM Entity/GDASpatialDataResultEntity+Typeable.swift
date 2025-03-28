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
        case .park:
            return isPark()
        case .bank:
            return isBank()
        case .grocery:
            return isGrocery()
        }
    }
    
    func isOfType(_ type: SecondaryType) -> Bool {
        switch type {
        case .transitStop:
            return isTransitStop()
        case .food:
            return isFood()
        case .park:
            return isPark()
        case .bank:
            return isBank()
        case .grocery:
            return isGrocery()
        }
    }
    
    private func isTransitStop() -> Bool {
        guard let category = SuperCategory(rawValue: superCategory) else {
            return false
        }
        let isTransitLocation = [.mobility, .navilens].contains(category) && localizedName.lowercased().contains(GDLocalizedString("osm.tag.bus_stop").lowercased())

        return isTransitLocation
    }

    /// All filters follow the same pattern: is amenity any one of a set of tags?
    private func isAnyOf(tags: Array<String>) -> Bool {
        return tags.contains(amenity)
    }

    private func isFood() -> Bool {
        return isAnyOf(tags: [
            "restaurant", "fast_food", "cafe", "bar", "ice_cream", "pub",
            "coffee_shop"
        ]);
    }

    private func isPark() -> Bool {
        return isAnyOf(tags: [
            "park", "garden", "green_space", "recreation_area", "playground",
            "nature_reserve", "botanical_garden", "public_garden", "field", "reserve"
        ]);
    }

    private func isBank() -> Bool {
        return isAnyOf(tags: ["bank", "atm"]);
    }

    private func isGrocery() -> Bool {
        return isAnyOf(tags: ["convenience", "supermarket"]);
    }
}
