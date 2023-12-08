//
//  GDASpatialDataResultEntity+Distance.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation

extension GDASpatialDataResultEntity {
    
    func closestEntrance(from location: CLLocation) -> POI? {
        guard let entrances = entrances else {
            return nil
        }
        
        var closestEntrance: POI?
        var minimumDistance = CLLocationDistanceMax
        
        for entrance in entrances {
            let distance = entrance.distanceToClosestLocation(from: location)
            
            if distance < minimumDistance {
                closestEntrance = entrance
                minimumDistance = distance
            }
        }
        
        return closestEntrance
    }
    
    func closestEdge(from location: CLLocationCoordinate2D) -> CLLocationCoordinate2D? {
        return geometry?.closestEdge(to: location)
    }
    
}
