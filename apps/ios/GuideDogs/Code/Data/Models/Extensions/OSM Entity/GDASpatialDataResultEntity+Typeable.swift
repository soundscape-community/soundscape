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
        guard let category = SuperCategory(rawValue: superCategory) else {
            return false
        }
        print("category: \(category)")
        let isTransitLocation = category == .mobility && localizedName.lowercased().contains(GDLocalizedString("osm.tag.bus_stop").lowercased())
        print("tranist: \(isTransitLocation)")
        if isTransitLocation {
            print("Transit location found: \(localizedName)")
        }
        return isTransitLocation
//        return category == .mobility && localizedName.lowercased().contains(GDLocalizedString("osm.tag.bus_stop").lowercased())
        
    }

    private func isFood() -> Bool {
        guard let category = SuperCategory(rawValue: superCategory) else {
            return false
        }
        print("categroy: \(category)")
        let isFoodLocation = category == .food && localizedName.lowercased().contains(GDLocalizedString("osm.tag.restaurant").lowercased())
        print("FOOD: \(isFoodLocation)")
        if isFoodLocation {
            print("Food location found: \(localizedName)")
        }
        
        return isFoodLocation
    }
    
    private func isLandmarks() -> Bool {
        guard let category = SuperCategory(rawValue: superCategory) else {
            return false
        }
        print("category: \(category)")
        let isLandmarkLocation = category == .landmarks && localizedName.lowercased().contains(GDLocalizedString("osm.tag.landmark").lowercased())
        print("LANDMARK: \(isLandmarkLocation)")
        if isLandmarkLocation {
            print("Landmark location found: \(localizedName)")
        }
        
        return isLandmarkLocation
    }
    
    private func isBusiness() -> Bool {
        return false
    }
    
    private func isHotel() -> Bool {
        return false
    }
}
