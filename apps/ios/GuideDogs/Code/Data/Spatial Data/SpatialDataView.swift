//
//  SpatialDataView.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import CoreLocation

@MainActor
class SpatialDataView: SpatialDataViewProtocol {
    
    // MARK: Private Properties

    /// Tile data encompassed by the current spatial data view
    private let tiles: [TileData]
    
    /// The current destination
    private let destination: POI?
    
    // The current set of user defined PORs
    private let genericLocations: [POI]
    
    /// A set of OSM IDs used to prevent duplicate entities when merging entities across tiles
    private var ids: Set<String> = []
    
    // MARK: Public Properties
    
    let markedPoints: [ReferenceEntity]
    
    /// Aggregated list of all POIs in the current spatial data view
    lazy var pois: [POI] = {
        var pois: [POI] = []
        
        for marker in markedPoints {
            let poi = marker.getPOI()
            
            // Add POI
            ids.insert(poi.key)
            pois.append(poi)
            
            if let matchable = poi as? MatchablePOI {
                for key in matchable.matchKeys {
                    // Add all keys for matching POIs
                    // to avoid duplicate POIs
                    ids.insert(key)
                }
            }
        }
        
        // Make sure any destinations not in the current tiles still get added to the list of POIs
        if let destinationEntity = destination, !ids.contains(destinationEntity.key) {
            ids.insert(destinationEntity.key)
            pois.append(destinationEntity)
            
            if let matchable = destinationEntity as? MatchablePOI {
                for key in matchable.matchKeys {
                    // Add all keys for matching POIs
                    // to avoid duplicate POIs
                    ids.insert(key)
                }
            }
        }
        
        // Gather all of the POIs (excluding entrances since they are special)
        for tile in tiles {
            for poi in tile.pois {
                guard poi.superCategory != SuperCategory.entrances.rawValue, !ids.contains(poi.key) else {
                    continue
                }
                
                ids.insert(poi.key)
                pois.append(poi)
                
                if let matchable = poi as? MatchablePOI {
                    for key in matchable.matchKeys {
                        // Add all keys for matching POIs
                        // to avoid duplicate POIs
                        ids.insert(key)
                    }
                }
            }
        }
        
        // Make sure any pors in the current tiles still get added to the list of POIs
        for poi in genericLocations where !ids.contains(poi.key) {
            ids.insert(poi.key)
            pois.append(poi)
            
            if let matchable = poi as? MatchablePOI {
                for key in matchable.matchKeys {
                    // Add all keys for matching POIs
                    // to avoid duplicate POIs
                    ids.insert(key)
                }
            }
        }
        
        return pois
    }()
    
    /// Aggregated list of all intersections in the current spatial data view.
    lazy var intersections: [Intersection] = {
        var intersections: [Intersection] = []
        
        for tile in tiles {
            for intersection in tile.intersections {
                guard !ids.contains(intersection.key) else {
                    continue
                }
                
                ids.insert(intersection.key)
                intersections.append(intersection)
            }
        }
        
        return intersections
    }()
    
    /// Aggregated list of all roads in the current spatial data view
    lazy var roads: [Road] = {
        var roads: [Road] = []
        
        for tile in tiles {
            for road in tile.roads {
                guard !ids.contains(road.key) else {
                    continue
                }
                
                ids.insert(road.key)
                roads.append(road)
            }
        }
        
        return roads
    }()
    
    // MARK: - Initialization
    
    /// Initializer
    ///
    /// - Parameters:
    ///   - tiles: Tile data in the current view window
    ///   - markedPoints: Marker entities in the current view window
    ///   - genericLocations: Generic locations in the current view window
    ///   - destination: Current destination, if set
    init(tiles: [TileData], markedPoints: [ReferenceEntity], genericLocations: [POI], destination: POI?) {
        self.tiles = tiles
        self.markedPoints = markedPoints
        self.genericLocations = genericLocations
        self.destination = destination
    }
    
    // MARK: - Class Methods

    /// Returns a POI filter used by a user activity.
    /// - Note: If the user activity does not requires a specific filter, `nil` will be returned.
    ///
    /// - Parameter motionActivity: A motion activity that encapsulates the user activity
    /// - Returns: The specific filter for the user activity, or `nil`
    class func filter(for motionActivity: MotionActivityProtocol) -> FilterPredicate? {
        if motionActivity.isInVehicle {
            // In a vehicle we only care about landmarks and bus stops
            return CompoundPredicate(orPredicateWithSubpredicates: [Filter.superCategory(expected: SuperCategory.landmarks),
                                                                    Filter.type(expected: SecondaryType.transitStop)])
        }
        return nil
    }
}
