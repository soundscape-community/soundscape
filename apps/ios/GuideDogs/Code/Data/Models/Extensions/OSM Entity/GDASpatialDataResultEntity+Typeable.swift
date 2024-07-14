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
        case .education:
            return isEducation()
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
        case .education:
            return isEducation()
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
        
        return category == .mobility && localizedName.lowercased().contains(GDLocalizedString("osm.tag.bus_stop").lowercased())
    }

    private func isFood() -> Bool {
        guard let category = SuperCategory(rawValue: superCategory) else {
            return false
        }
        let isFoodLocation = category == .food && localizedName.lowercased().contains(GDLocalizedString("osm.tag.restaurant").lowercased())
        
        if isFoodLocation {
            print("Food location found: \(localizedName)")
        }
        
        return isFoodLocation
    }
    
    private func isEducation() -> Bool {
        return false
    }
    
    private func isBusiness() -> Bool {
        return false
    }
    
    private func isHotel() -> Bool {
        return false
    }
}
