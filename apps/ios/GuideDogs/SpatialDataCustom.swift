//
//  SpatialDataCustom.swift
//  Soundscape
//
//  Created by Kai on 11/28/23.
//  Copyright © 2023 Soundscape community. All rights reserved.
//

import Foundation
import CoreLocation
import RealmSwift

/// Manages the ``RealmHelper.database`` realm
class SpatialDataCustom {
    
    struct Predicates {
        
        static func nickname(_ text: String) -> NSPredicate {
            return NSPredicate(format: "nickname CONTAINS[c] %@", text)
        }
        
        static let lastSelectedDate = NSPredicate(format: "lastSelectedDate != NULL")
        
        static func distance(_ coordinate: CLLocationCoordinate2D,
                             span: CLLocationDistance? = nil,
                             latKey: String = "centroidLatitude",
                             lonKey: String = "centroidLongitude") -> NSPredicate {
            let range = span ?? SpatialDataContext.cacheDistance * 2
            
            return NSPredicate(centerCoordinate: coordinate,
                               span: range, /* `span` is the diameter */
                               latitudeKey: latKey,
                               longitudeKey: lonKey)
        }

        static func isTemporary(_ flag: Bool) -> NSPredicate {
            return NSPredicate(format: "isTemp = %@", NSNumber(value: flag))
        }
    }
    
    
    // MARK: Routes
    
    static func routeByKey(_ key: String) -> Route? {
        return autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                return nil
            }
            
            return database.object(ofType: Route.self, forPrimaryKey: key)
        }
    }
    
    static func routes(withPredicate predicate: NSPredicate? = nil) -> [Route] {
        return autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                return []
            }
            
            let results: Results<Route>
            
            if let predicate = predicate {
                results = database.objects(Route.self).filter(predicate)
            } else {
                results = database.objects(Route.self)
            }
            
            return Array(results)
        }
    }
    
    /// Sets all ``Route``s to `isNew = false`
    static func clearNewRoutes() throws {
        try autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                return
            }
            let newRoutes = database.objects(Route.self).filter({ $0.isNew })
            
            try database.write {
                for route in newRoutes {
                    route.isNew = false
                }
            }
        }
    }
    
    static func routesNear(_ coordinate: CLLocationCoordinate2D, range: CLLocationDistance) -> [Route] {
        let predicate = Predicates.distance(coordinate, span: range * 2, latKey: "firstWaypointLatitude", lonKey: "firstWaypointLongitude")
        return routes(withPredicate: predicate)
    }
    
    static func routesContaining(markerId: String) -> [Route] {
        let predicate = NSPredicate(format: "SUBQUERY(waypoints, $waypoint, $waypoint.markerId == %@).@count > 0", markerId)
        return routes(withPredicate: predicate)
    }
    
    // MARK: Reference Entities
    
    static func containsReferenceEntity(withKey key: String) -> Bool {
        return referenceEntityByKey(key) != nil
    }
    
    static func referenceEntities(with predicate: NSPredicate) -> [ReferenceEntity] {
        return autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                return []
            }
            
            return Array(database.objects(ReferenceEntity.self).filter(predicate))
        }
    }
    
    ///
    /// Returns reference entity objects where `object.isTemp == isTemp`
    ///
    /// Parameter: isTemp true if the returned objects should be marked as temporary and  false if the returned objects should not be marked as temporary
    ///
    static func referenceEntities(isTemp: Bool = false) -> [ReferenceEntity] {
        return referenceEntities(with: Predicates.isTemporary(isTemp))
    }
    
    static func referenceEntityByKey(_ key: String) -> ReferenceEntity? {
        return autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                return nil
            }
            
            return database.object(ofType: ReferenceEntity.self, forPrimaryKey: key)
        }
    }
    
    static func referenceEntityByEntityKey(_ key: String) -> ReferenceEntity? {
        return referenceEntities(with: NSPredicate(format: "entityKey = %@", key)).first ?? referenceEntityByKey(key)
    }
    
    ///
    /// Returns reference entity objects near the given coordinate and with the expected `isTemp` value (if expected value is provided)
    ///
    /// Parameters:
    /// - coordinate returns objects near the given coordiante
    /// - isTemp `nil` if objects should not be filtered by `isTemp`,  true if the returned objects should be marked as temporary and  false if the returned objects should not be marked as temporary
    ///
    static func referenceEntityByLocation(_ coordinate: CLLocationCoordinate2D, isTemp: Bool? = false) -> ReferenceEntity? {
        return referenceEntitiesNear(coordinate, range: 1.0, isTemp: isTemp).first
    }
    
    ///
    /// Returns reference entity objects near the given location and with the expected `isTemp` value (if expected value is provided)
    ///
    /// Parameters:
    /// - location returns objects near the given location
    /// - isTemp `nil` if objects should not be filtered by `isTemp`,  true if the returned objects should be marked as temporary and  false if the returned objects should not be marked as temporary
    ///
    static func referenceEntityByGenericLocation(_ location: GenericLocation, isTemp: Bool? = false) -> ReferenceEntity? {
        return referenceEntityByLocation(location.location.coordinate, isTemp: isTemp)
    }
    
    ///
    /// Returns reference entity objects matching the given source and with the expected `isTemp` value (if expected value is provided)
    ///
    /// Parameters:
    /// - source defines what the reference entity is based on
    /// - isTemp `nil` if objects should not be filtered by `isTemp`,  true if the returned objects should be marked as temporary and  false if the returned objects should not be marked as temporary
    ///
    static func referenceEntity(source: LocationDetail.Source, isTemp: Bool? = false) -> ReferenceEntity? {
        var marker: ReferenceEntity?
        
        switch source {
        case .entity(let id): marker = SpatialDataCustom.referenceEntityByEntityKey(id)
        case .coordinate(let location): marker = SpatialDataCustom.referenceEntityByLocation(location.coordinate, isTemp: isTemp)
        case .designData: marker = nil
        case .screenshots(let poi): marker = SpatialDataCustom.referenceEntityByEntityKey(poi.key)
        }
        
        if let isTemp = isTemp, let marker = marker {
            // Only return markers with the given value for `isTemp`
            return marker.isTemp == isTemp ? marker : nil
        } else {
            // Do not filter by `isTemp`
            return marker
        }
    }
    
    ///
    /// Returns reference entity objects near the given coordinate and with the expected `isTemp` value (if expected value is provided)
    ///
    /// Parameters:
    /// - coordinate returns objects near the given coordiante
    /// - range search distance in meters
    /// - isTemp `nil` if objects should not be filtered by `isTemp`,  true if the returned objects should be marked as temporary and  false if the returned objects should not be marked as temporary
    ///
    static func referenceEntitiesNear(_ coordinate: CLLocationCoordinate2D, range: CLLocationDistance, isTemp: Bool? = false) -> [ReferenceEntity] {
        var predicate: NSPredicate
        
        if let isTemp = isTemp {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                Predicates.distance(coordinate, span: range * 2, latKey: "latitude", lonKey: "longitude"),
                Predicates.isTemporary(isTemp)
            ])
        } else {
            predicate = Predicates.distance(coordinate, span: range * 2, latKey: "latitude", lonKey: "longitude")
        }
        
        return referenceEntities(with: predicate)
    }
    
    /// Loops through all ReferenceEntities with `isNew == true` and sets `isNew` to false
    static func clearNewReferenceEntities() throws {
        let newReferenceEntities = referenceEntities(with: NSPredicate(format: "isNew == true"))

        try autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                return
            }
            
            try database.write {
                for entity in newReferenceEntities {
                    entity.isNew = false
                }
            }
        }
    }
    
    // MARK: VectorTile Tools
    
    static func tilesForReferenceEntities(at zoomLevel: UInt) -> Set<VectorTile> {
        let referenceEntities = SpatialDataCustom.referenceEntities(isTemp: false)
        let tiles = referenceEntities.map { VectorTile(latitude: $0.latitude, longitude: $0.longitude, zoom: zoomLevel) }
        return Set(tiles)
    }
    
}
