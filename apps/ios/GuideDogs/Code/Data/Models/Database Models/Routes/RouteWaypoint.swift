//
//  RouteWaypoint.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import SSData

/*
 Represents the waypoints belonging to a route.
 
 Each waypoint in the `Route` object is represented by
 an existing `ReferenceEntity` (e.g., `markerId`) and an
 index that reflects the waypoint's ordering within the
 route.
 */
final class RouteWaypoint {
    
    typealias Completion = (Result<RouteWaypoint, Error>) -> Void
    
    // MARK: Properties
    
    // Represents the order that this waypoint will appear
    // in the `Route` object
    var index: Int = -1
    // `markerId` is the primary key for a `ReferenceEntity`
    // object
    var markerId: String = ""
    // Use `locationDetail` to persist waypoint and marker data that is
    // being imported from a URL resource and has not been added to the
    // user database (e.g., sharing activity)
    private var importedLocationDetail: LocationDetail?
    var importedDetail: LocationDetail? { importedLocationDetail }
    
    // This value should never be `nil`
    var asLocationDetail: LocationDetail? {
        // If there is imported data, return it
        // Otherwise, return saved data
        return importedLocationDetail ?? LocationDetail(markerId: markerId)
    }
    
    // MARK: Initialization
    
    /**
     * Initializes a waypoint from a marker that exists in the user database.
     *
     * - Parameters:
     *     - index: Index of the waypoint
     *     - markerId: ID for a marker that exists in user database
     */
    convenience init?(index: Int, markerId: String) {
        self.init()
        
        guard LocationDetail(markerId: markerId) != nil else {
            // Marker does not exist
            return nil
        }
        
        self.index = index
        self.markerId = markerId
        self.importedLocationDetail = nil
    }
    
    /**
     * Initializes a waypoint from a marker that exists in the user database.
     *
     * - Parameters:
     *     - index: Index of the waypoint
     *     - locationDetail: Data for a marker that exists in user database
     */
    convenience init?(index: Int, locationDetail: LocationDetail) {
        self.init()
        
        guard let markerId = locationDetail.markerId else {
            // Location is not a marker
            return nil
        }
        
        self.index = index
        self.markerId = markerId
        self.importedLocationDetail = nil
    }
    
    /**
     * Initializes a waypoint from a marker that is being imported from a URL resource (e.g.,
     * sharing activity) and has not been added to the user database.
     *
     * Initializer should only be called after fetching the associated marker data via `RouteParametersHandler`!
     *
     * - Parameters:
     *     - index: Index of the waypoint
     *     - markerId: ID for imported marker
     *     - importedLocationDetail: Data for marker that is being imported
     */
    convenience init(index: Int, markerId: String, importedLocationDetail: LocationDetail) {
        self.init()
        
        self.index = index
        self.markerId = markerId
        self.importedLocationDetail = importedLocationDetail
    }
    
    convenience init(stored: Waypoint) {
        self.init()
        
        index = stored.index
        markerId = stored.markerId
    }
    
    var stored: Waypoint { Waypoint(markerId: markerId, index: index) }
}

extension Array where Element == RouteWaypoint {
    
    var ordered: [RouteWaypoint] {
        return self.sorted(by: { return $0.index < $1.index })
    }
    
    var asLocationDetail: [LocationDetail] {
        return self.compactMap({ return $0.asLocationDetail })
    }
    
}
