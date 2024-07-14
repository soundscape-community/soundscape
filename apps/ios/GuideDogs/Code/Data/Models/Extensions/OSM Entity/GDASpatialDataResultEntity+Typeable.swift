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
        case .park:
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
        // Implement your logic for food type
        return false
    }
    
    private func isEducation() -> Bool {
        // Implement your logic for park type
        return false
    }
    
    private func isBusiness() -> Bool {
        // Implement your logic for business type
        return false
    }
    
    private func isHotel() -> Bool {
        // Implement your logic for hotel type
        return false
    }
}
