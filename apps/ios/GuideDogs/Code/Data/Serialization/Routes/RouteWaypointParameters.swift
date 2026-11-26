//
//  RouteWaypointParameters.swift
//  SoundscapeUnitTests
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation

/*
 Supports serialization of a route waypoint
 */
struct RouteWaypointParameters: Codable {
    
    // MARK: Properties
    
    let index: Int
    let markerId: String
    // Shared documents include marker details for offline import.
    let marker: MarkerParameters?
    
    // MARK: Initialization
    
    init(index: Int, markerId: String, marker: MarkerParameters?) {
        self.index = index
        self.markerId = markerId
        self.marker = marker
    }
    
    init(waypoint: RouteWaypoint) {
        let index = waypoint.index
        let markerId = waypoint.markerId
        let marker = MarkerParameters(markerId: markerId)
        
        self.init(index: index, markerId: markerId, marker: marker)
    }
    
}
