//
//  SecondaryType.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

enum SecondaryType: Type {
    
    case transitStop
    case food
    case landmarks
    case park
    case hotel
    
    func matches(poi: POI) -> Bool {
        guard let typeable = poi as? Typeable else {
            return false
        }
        
        return typeable.isOfType(self)
    }
    
}
