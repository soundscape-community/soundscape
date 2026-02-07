//
//  Route+Realm.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import RealmSwift
import CoreLocation

@MainActor
protocol RouteSpatialDataStore {
    func referenceEntityByKey(_ key: String) -> ReferenceEntity?
    func routes() -> [Route]
    func routeByKey(_ key: String) -> Route?
    func routesContaining(markerId: String) -> [Route]
}

@MainActor
struct DefaultRouteSpatialDataStore: RouteSpatialDataStore {
    func referenceEntityByKey(_ key: String) -> ReferenceEntity? {
        SpatialDataCache.referenceEntityByKey(key)
    }

    func routes() -> [Route] {
        SpatialDataCache.routes()
    }

    func routeByKey(_ key: String) -> Route? {
        SpatialDataCache.routeByKey(key)
    }

    func routesContaining(markerId: String) -> [Route] {
        SpatialDataCache.routesContaining(markerId: markerId)
    }
}

@MainActor
enum RouteSpatialDataStoreRegistry {
    private static let defaultStore = DefaultRouteSpatialDataStore()
    private(set) static var store: RouteSpatialDataStore = defaultStore

    static func configure(with store: RouteSpatialDataStore) {
        self.store = store
    }

    static func resetForTesting() {
        store = defaultStore
    }
}

@MainActor
extension Route {
    
    // MARK: Query All Routes
    
    static func object(forPrimaryKey key: String) -> Route? {
        return autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                return nil
            }
            
            return database.object(ofType: Route.self, forPrimaryKey: key)
        }
    }
    
    static func objectKeys(sortedBy: SortStyle) -> [String] {
        return autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                return []
            }
            
            switch sortedBy {
            case .alphanumeric:
                return database.objects(Route.self)
                    .sorted(by: { $0.name < $1.name })
                    .compactMap({ $0.id })
                
            case .distance:
                let userLocation = RouteRuntime.currentUserLocation() ?? CLLocation(latitude: 0.0, longitude: 0.0)
                
                return database.objects(Route.self)
                    .compactMap { route -> (id: String, distance: CLLocationDistance)? in
                        guard let start = route.waypoints.ordered.first,
                              let entity = RouteSpatialDataStoreRegistry.store.referenceEntityByKey(start.markerId) else {
                            return (id: route.id, distance: CLLocationDistance.greatestFiniteMagnitude)
                        }
                        
                        return (id: route.id, distance: entity.distanceToClosestLocation(from: userLocation))
                    }
                    .sorted { $0.distance < $1.distance }
                    .compactMap({ $0.id })
            }
        }
    }
    
    /// Async version of objectKeys for background sorting/filtering without blocking main actor
    static func asyncObjectKeys(sortedBy: SortStyle) async -> [String] {
        return await Task.detached(priority: .utility) {
            await MainActor.run {
                objectKeys(sortedBy: sortedBy)
            }
        }.value
    }
    
    /// Finds a route by name in the Realm database
    static func routeWithName(_ name: String) -> Route? {
        return autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                return nil
            }
            
            return database.objects(Route.self)
                .filter("name == %@", name)
                .first
        }
    }
    
    // MARK: Add or Delete Routes
    
    static func add(_ route: Route, context: String? = nil) throws {
        try autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                throw RouteRealmError.databaseError
            }
            
            // If necessary, save a marker for each waypoint
            try route.waypoints.forEach({
                guard let locationDetail = $0.asLocationDetail else {
                    return
                }
                
                let markerId = try ReferenceEntity.add(detail: locationDetail, telemetryContext: "add_route", notify: false)
                
                // `markerId` will change when adding a new Realm object
                // `markerId` will not change when updating an existing Realm object
                $0.markerId = markerId
            })
            
            if let existingRoute = database.object(ofType: Route.self, forPrimaryKey: route.id) {
                try update(id: existingRoute.id, name: route.name, description: route.routeDescription, waypoints: route.waypoints)
                
                RouteRuntime.updateRouteInCloud(route)
            } else {
                try database.write {
                    database.add(route, update: .modified)
                }
                
                RouteRuntime.storeRouteInCloud(route)
                
                let id = route.id
                
                NotificationCenter.default.post(name: .routeAdded, object: self, userInfo: [Route.Keys.id: id])
                GDATelemetry.track("routes.added", with: ["context": context ?? "none", "activity": RouteRuntime.currentMotionActivityRawValue()])
            }
        }
    }
    
    static func delete(_ id: String) throws {
        try autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                throw RouteRealmError.databaseError
            }
            
            guard let route = database.object(ofType: Route.self, forPrimaryKey: id) else {
                throw RouteRealmError.doesNotExist
            }
            
            // Unlink reversed route if it exists
            if let reversedId = route.reversedRouteId,
               let reversedRoute = database.object(ofType: Route.self, forPrimaryKey: reversedId) {
                try database.write {
                    reversedRoute.reversedRouteId = nil
                }
            }
            
            // `delete` should never be called when a route is active, but just in case it is,
            // deactive the route behavior to prevent unknown consequences of deleting active route
            if route.isActive {
                RouteRuntime.deactivateActiveBehavior()
            }
            
            RouteRuntime.removeRouteFromCloud(route)
            
            try database.write {
                database.delete(route)
            }
            
            NotificationCenter.default.post(name: .routeDeleted, object: self, userInfo: [Route.Keys.id: id])
            GDATelemetry.track("routes.removed")
        }
    }
    
    static func deleteAll() throws {
        try RouteSpatialDataStoreRegistry.store.routes().forEach({
            try delete($0.id)
        })
    }
    
    // MARK: Update Routes
    
    private static func onRouteDidUpdate(_ route: Route) {
        RouteRuntime.updateRouteInCloud(route)

        NotificationCenter.default.post(name: .routeUpdated, object: self, userInfo: [Route.Keys.id: route.id])
        GDATelemetry.track("routes.edited", with: ["activity": RouteRuntime.currentMotionActivityRawValue()])
    }
    
    static func updateLastSelectedDate(id: String, _ lastSelectedDate: Date = Date()) throws {
        try autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                throw RouteRealmError.databaseError
            }
            
            guard let route = database.object(ofType: Route.self, forPrimaryKey: id) else {
                throw RouteRealmError.doesNotExist
            }
            
            try database.write {
                route.lastSelectedDate = lastSelectedDate
            }
            
            onRouteDidUpdate(route)
        }
    }
    
    static func update(id: String, name: String, description: String?, waypoints: List<RouteWaypoint>) throws {
        try autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                throw RouteRealmError.databaseError
            }
            
            guard let route = database.object(ofType: Route.self, forPrimaryKey: id) else {
                throw RouteRealmError.doesNotExist
            }
            
            // `update` should never be called when a route is active,
            // but just in case it is, deactive the route behavior to prevent unknown
            // consequences of updating waypoints in an active route
            if route.isActive {
                RouteRuntime.deactivateActiveBehavior()
            }
            
            try database.write {
                // Unlink reversed route if waypoints have changed
                if let existingReversedId = route.reversedRouteId,
                   let reversedRoute = database.object(ofType: Route.self, forPrimaryKey: existingReversedId),
                   !isWaypointsEqual(route, reversedRoute) {

                    // Unlink both routes
                    route.reversedRouteId = nil
                    reversedRoute.reversedRouteId = nil
                }
                
                route.name = name
                route.routeDescription = description
                route.waypoints = waypoints
                // Update `lastSelectedDate` and `lastUpdatedDate`
                let lastSelectedAndUpdatedDate = Date()
                route.lastSelectedDate = lastSelectedAndUpdatedDate
                route.lastUpdatedDate = lastSelectedAndUpdatedDate
                
                // Update first waypoint latitude and longitude
                if let first = waypoints.ordered.first,
                   let marker = RouteSpatialDataStoreRegistry.store.referenceEntityByKey(first.markerId) {
                    route.firstWaypointLatitude = marker.latitude
                    route.firstWaypointLongitude = marker.longitude
                } else {
                    route.firstWaypointLatitude = nil
                    route.firstWaypointLongitude = nil
                }
            }
            
            onRouteDidUpdate(route)
        }
    }
    
    static func update(id: String, name: String, description: String?, waypoints: [LocationDetail]) throws {
        // `LocationDetail` -> `RouteWaypoint`
        let wRealmObjects = waypoints.enumerated().compactMap({ return RouteWaypoint(index: $0, locationDetail: $1) })
        
        // Append waypoints to a Realm list
        let wList = List<RouteWaypoint>()
        wRealmObjects.forEach({ wList.append($0) })
        
        try update(id: id, name: name, description: description, waypoints: wList)
    }
    
    // MARK: Add, Delete or Update Route Waypoints
    
    static func removeWaypoint(from route: Route, markerId: String) throws {
        // Currently, a marker cannot be added to a route more than once, so `firstIndex`
        // will return the only instance of `markerId`
        guard let index = route.waypoints.firstIndex(where: { $0.markerId == markerId }) else {
            return
        }
        
        // Create a copy of the route waypoints
        let waypoints: List<RouteWaypoint> = List<RouteWaypoint>()
        route.waypoints.forEach({
            waypoints.append(RouteWaypoint(value: $0))
        })
        
        // Save the waypoint index
        let waypointIndex = waypoints[index].index
        
        waypoints.remove(at: index)
        
        // Update the remaining waypoint indices
        waypoints.forEach({
            if $0.index > waypointIndex {
                $0.index -= 1
            }
        })
        
        try update(id: route.id, name: route.name, description: route.routeDescription, waypoints: waypoints)
    }
    
    static func removeWaypointFromAllRoutes(markerId: String) throws {
        try RouteSpatialDataStoreRegistry.store.routesContaining(markerId: markerId).forEach({
            try removeWaypoint(from: $0, markerId: markerId)
        })
    }
    
    static func updateWaypointInAllRoutes(markerId: String) throws {
        try RouteSpatialDataStoreRegistry.store.routesContaining(markerId: markerId).forEach({
            guard let first = $0.waypoints.ordered.first else {
                return
            }
            
            guard first.markerId == markerId else {
                return
            }
            
            // Update the first waypoint
            try update(id: $0.id, name: $0.name, description: $0.routeDescription, waypoints: $0.waypoints)
        })
    }
    
    // MARK: Reverse a route
    
    /// Creates a new Route instance with the order of waypoints reversed.
    static func reversedRoute(from route: Route) -> Route? {
        // Ensure there is at least one waypoint.
        guard !route.waypoints.isEmpty else { return nil }

        let orderedWaypoints = route.waypoints.ordered
        let reversedWaypoints = orderedWaypoints.reversed().enumerated().compactMap { (index, waypoint) -> RouteWaypoint? in
            return RouteWaypoint(index: index, markerId: waypoint.markerId)
        }
        
        let newName = GDLocalizedString("routes.reverse_name_format", route.name)

        let newRoute = Route(name: newName, description: route.routeDescription, waypoints: reversedWaypoints)
        return newRoute
    }

    /// Checks whether two routes have the same ordered waypoints.
    static func isWaypointsEqual(_ route1: Route, _ route2: Route) -> Bool {
        let route1IDs = route1.waypoints.ordered.map { $0.markerId }
        let route2IDs = route2.waypoints.ordered.map { $0.markerId }
        return route1IDs == route2IDs
    }
    
    /// Generates and adds a reversed version of the route, handling duplicate name conflicts.
    static func createReversedRoute(from route: Route) throws -> Route? {
        // If route already has a reversedRouteId, return that route
        if let reversedId = route.reversedRouteId,
           let existing = Route.object(forPrimaryKey: reversedId) {
            return existing
        }

        guard let reversed = reversedRoute(from: route) else { return nil }

        // Resolve naming conflicts
        var finalName = reversed.name
        var index = 2
        while let existing = Route.routeWithName(finalName) {
            if isWaypointsEqual(existing, reversed) {
                return existing
            }
            finalName = "\(reversed.name) (\(index))"
            index += 1
        }
        reversed.name = finalName

        // Add and link reversed route
        try Route.add(reversed)
        try autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                throw RouteRealmError.databaseError
            }
            try database.write {
                route.reversedRouteId = reversed.id
                reversed.reversedRouteId = route.id
            }
        }

        return reversed
    }
}
