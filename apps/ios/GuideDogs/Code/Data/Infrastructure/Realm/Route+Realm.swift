//
//  Route+Realm.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import RealmSwift
import CoreLocation

@MainActor
extension Route {
    private static func resolvedFirstWaypointCoordinate(for route: Route, preferredCoordinate: CLLocationCoordinate2D?) -> CLLocationCoordinate2D? {
        if let preferredCoordinate {
            return preferredCoordinate
        }

        if let routeCoordinate = route.firstWaypointLocation?.coordinate {
            return routeCoordinate
        }

        return firstWaypointCoordinate(for: route.waypoints)
    }

    private static func resolvedReversedRouteName(for reversedRoute: Route) -> (name: String, existingRoute: Route?) {
        var finalName = reversedRoute.name
        var index = 2

        while let existing = Route.routeWithName(finalName) {
            if isWaypointsEqual(existing, reversedRoute) {
                return (name: finalName, existingRoute: existing)
            }

            finalName = "\(reversedRoute.name) (\(index))"
            index += 1
        }

        return (name: finalName, existingRoute: nil)
    }

    private static func addReferenceEntity(for locationDetail: LocationDetail,
                                           telemetryContext: String?,
                                           notify: Bool,
                                           using spatialRead: ReferenceReadContract) async throws -> String {
        if let id = locationDetail.markerId,
           let marker = SpatialDataStoreRegistry.store.referenceEntityByKey(id) {
            try await RealmReferenceEntity.update(entity: marker,
                                                  location: locationDetail.location.coordinate,
                                                  nickname: locationDetail.nickname,
                                                  address: locationDetail.estimatedAddress,
                                                  annotation: locationDetail.annotation,
                                                  context: telemetryContext,
                                                  isTemp: false,
                                                  using: spatialRead)
            return id
        }

        switch locationDetail.source {
        case .coordinate(let at):
            let location = GenericLocation(lat: at.coordinate.latitude,
                                           lon: at.coordinate.longitude)
            return try await RealmReferenceEntity.add(location: location,
                                                      nickname: locationDetail.nickname,
                                                      estimatedAddress: locationDetail.estimatedAddress,
                                                      annotation: locationDetail.annotation,
                                                      temporary: false,
                                                      context: telemetryContext,
                                                      notify: notify,
                                                      using: spatialRead)
        case .entity(let id):
            return try await RealmReferenceEntity.add(entityKey: id,
                                                      nickname: locationDetail.nickname,
                                                      estimatedAddress: locationDetail.estimatedAddress,
                                                      annotation: locationDetail.annotation,
                                                      context: telemetryContext,
                                                      notify: notify,
                                                      using: spatialRead)
        case .designData, .screenshots:
            throw ReferenceEntityError.cannotAddMarker
        }
    }

    private static func persistAddedRoute(_ route: Route,
                                          firstWaypointCoordinate: CLLocationCoordinate2D? = nil) throws {
        try autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                throw RouteRealmError.databaseError
            }

            var route = route
            let persistedFirstWaypointCoordinate = resolvedFirstWaypointCoordinate(for: route,
                                                                                  preferredCoordinate: firstWaypointCoordinate)
            route.firstWaypointLatitude = persistedFirstWaypointCoordinate?.latitude
            route.firstWaypointLongitude = persistedFirstWaypointCoordinate?.longitude

            if let existingRoute = database.object(ofType: RealmRoute.self, forPrimaryKey: route.id) {
                try update(id: existingRoute.id,
                           name: route.name,
                           description: route.routeDescription,
                           waypoints: route.waypoints,
                           firstWaypointCoordinate: persistedFirstWaypointCoordinate)

                RouteRuntime.updateRouteInCloud(route)
            } else {
                try database.write {
                    database.add(RealmRoute(route: route, firstWaypointCoordinate: persistedFirstWaypointCoordinate), update: .modified)
                }

                RouteRuntime.storeRouteInCloud(route)

                let id = route.id

                NotificationCenter.default.post(name: .routeAdded, object: self, userInfo: [Route.Keys.id: id])
                GDATelemetry.track("routes.added", with: ["context": "none", "activity": RouteRuntime.currentMotionActivityRawValue()])
            }
        }
    }
    
    // MARK: Query All Routes
    
    static func object(forPrimaryKey key: String) -> Route? {
        return autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                return nil
            }
            
            return database.object(ofType: RealmRoute.self, forPrimaryKey: key)?.domainModel
        }
    }
    
    static func objectKeys(sortedBy: SortStyle) -> [String] {
        return autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                return []
            }
            
            switch sortedBy {
            case .alphanumeric:
                return database.objects(RealmRoute.self)
                    .sorted(by: { $0.name < $1.name })
                    .compactMap({ $0.id })
                
            case .distance:
                let userLocation = RouteRuntime.currentUserLocation() ?? CLLocation(latitude: 0.0, longitude: 0.0)
                
                return database.objects(RealmRoute.self)
                    .compactMap { route -> (id: String, distance: CLLocationDistance)? in
                        guard let start = route.waypoints.ordered.first else {
                            return (id: route.id, distance: CLLocationDistance.greatestFiniteMagnitude)
                        }

                        let distance = SpatialDataStoreRegistry.store.referenceEntityByKey(start.markerId)?
                            .distanceToClosestLocation(from: userLocation)
                            ?? CLLocationDistance.greatestFiniteMagnitude

                        return (id: route.id, distance: distance)
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
            
            return database.objects(RealmRoute.self)
                .filter("name == %@", name)
                .first?.domainModel
        }
    }
    
    // MARK: Add or Delete Routes

    /// Imports a route payload from cloud sync without route mutation side effects
    /// such as telemetry, notifications, or cloud write-back.
    static func importFromCloud(_ route: Route, firstWaypointCoordinate: CLLocationCoordinate2D? = nil) throws {
        try autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                throw RouteRealmError.databaseError
            }

            let persistedFirstWaypointCoordinate = resolvedFirstWaypointCoordinate(for: route,
                                                                                  preferredCoordinate: firstWaypointCoordinate)
            let persistedRoute = RealmRoute(route: route,
                                            firstWaypointCoordinate: persistedFirstWaypointCoordinate)

            try database.write {
                database.add(persistedRoute, update: .modified)
            }
        }
    }
    
    static func add(_ route: Route,
                    firstWaypointCoordinate: CLLocationCoordinate2D? = nil,
                    using spatialRead: ReferenceReadContract) async throws {
        var route = route

        for index in route.waypoints.indices {
            guard let locationDetail = await route.waypoints[index].locationDetail(using: spatialRead) else {
                continue
            }

            let markerId = try await addReferenceEntity(for: locationDetail,
                                                        telemetryContext: "add_route",
                                                        notify: false,
                                                        using: spatialRead)
            route.waypoints[index].markerId = markerId
        }

        try persistAddedRoute(route, firstWaypointCoordinate: firstWaypointCoordinate)
    }
    
    static func delete(_ id: String) throws {
        try autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                throw RouteRealmError.databaseError
            }
            
            guard let route = database.object(ofType: RealmRoute.self, forPrimaryKey: id) else {
                throw RouteRealmError.doesNotExist
            }
            
            // Unlink reversed route if it exists
            if let reversedId = route.reversedRouteId,
               let reversedRoute = database.object(ofType: RealmRoute.self, forPrimaryKey: reversedId) {
                try database.write {
                    route.unlinkReversedRoute(reversedRoute)
                }
            }
            
            // `delete` should never be called when a route is active, but just in case it is,
            // deactive the route behavior to prevent unknown consequences of deleting active route
            if route.isActive {
                RouteRuntime.deactivateActiveBehavior()
            }
            
            RouteRuntime.removeRouteFromCloud(route.domainModel)
            
            try database.write {
                database.delete(route)
            }
            
            NotificationCenter.default.post(name: .routeDeleted, object: self, userInfo: [Route.Keys.id: id])
            GDATelemetry.track("routes.removed")
        }
    }
    
    static func deleteAll() throws {
        try SpatialDataStoreRegistry.store.routes().forEach({
            try delete($0.id)
        })
    }
    
    // MARK: Update Routes
    
    private static func onRouteDidUpdate(_ route: RealmRoute) {
        RouteRuntime.updateRouteInCloud(route.domainModel)

        NotificationCenter.default.post(name: .routeUpdated, object: self, userInfo: [Route.Keys.id: route.id])
        GDATelemetry.track("routes.edited", with: ["activity": RouteRuntime.currentMotionActivityRawValue()])
    }
    
    static func updateLastSelectedDate(id: String, _ lastSelectedDate: Date = Date()) throws {
        try autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                throw RouteRealmError.databaseError
            }
            
            guard let route = database.object(ofType: RealmRoute.self, forPrimaryKey: id) else {
                throw RouteRealmError.doesNotExist
            }
            
            try database.write {
                route.lastSelectedDate = lastSelectedDate
            }
            
            onRouteDidUpdate(route)
        }
    }
    
    static func update(id: String,
                       name: String,
                       description: String?,
                       waypoints: [RouteWaypoint],
                       firstWaypointCoordinate: CLLocationCoordinate2D? = nil) throws {
        try autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                throw RouteRealmError.databaseError
            }
            
            guard let route = database.object(ofType: RealmRoute.self, forPrimaryKey: id) else {
                throw RouteRealmError.doesNotExist
            }
            
            // `update` should never be called when a route is active,
            // but just in case it is, deactive the route behavior to prevent unknown
            // consequences of updating waypoints in an active route
            if route.isActive {
                RouteRuntime.deactivateActiveBehavior()
            }

            let persistedFirstWaypointCoordinate = firstWaypointCoordinate
                ?? self.firstWaypointCoordinate(for: waypoints)
            
            try database.write {
                // Unlink reversed route if waypoints have changed
                if let existingReversedId = route.reversedRouteId,
                   let reversedRoute = database.object(ofType: RealmRoute.self, forPrimaryKey: existingReversedId),
                   !isWaypointsEqual(route.domainModel, reversedRoute.domainModel) {
                    route.unlinkReversedRoute(reversedRoute)
                }
                
                route.applyRouteUpdate(name: name,
                                       routeDescription: description,
                                       waypoints: waypoints,
                                       firstWaypointCoordinate: persistedFirstWaypointCoordinate,
                                       at: Date())
            }
            
            onRouteDidUpdate(route)
        }
    }

    static func update(id: String,
                       name: String,
                       description: String?,
                       waypoints: [RouteWaypoint],
                       firstWaypointCoordinate: CLLocationCoordinate2D? = nil,
                       using spatialRead: ReferenceReadContract) async throws {
        let resolvedFirstWaypointCoordinate: CLLocationCoordinate2D?
        if let firstWaypointCoordinate {
            resolvedFirstWaypointCoordinate = firstWaypointCoordinate
        } else {
            resolvedFirstWaypointCoordinate = await self.firstWaypointCoordinate(for: waypoints, using: spatialRead)
        }

        try update(id: id,
                   name: name,
                   description: description,
                   waypoints: waypoints,
                   firstWaypointCoordinate: resolvedFirstWaypointCoordinate)
    }
    
    static func update(id: String,
                       name: String,
                       description: String?,
                       waypoints: [LocationDetail],
                       firstWaypointCoordinate: CLLocationCoordinate2D? = nil) throws {
        // `LocationDetail` -> `RouteWaypoint`
        let wRealmObjects = waypoints.enumerated().compactMap({ return RouteWaypoint(index: $0, locationDetail: $1) })

        try update(id: id,
                   name: name,
                   description: description,
                   waypoints: wRealmObjects,
                   firstWaypointCoordinate: firstWaypointCoordinate)
    }
    
    // MARK: Add, Delete or Update Route Waypoints
    
    static func removeWaypoint(from route: Route,
                               markerId: String,
                               using spatialRead: ReferenceReadContract) async throws {
        guard let index = route.waypoints.firstIndex(where: { $0.markerId == markerId }) else {
            return
        }

        var waypoints = route.waypoints
        let waypointIndex = waypoints[index].index
        waypoints.remove(at: index)

        for i in waypoints.indices where waypoints[i].index > waypointIndex {
            waypoints[i].index -= 1
        }

        try await update(id: route.id,
                         name: route.name,
                         description: route.routeDescription,
                         waypoints: waypoints,
                         using: spatialRead)
    }
    
    static func removeWaypointFromAllRoutes(markerId: String,
                                            using spatialRead: ReferenceReadContract) async throws {
        for route in SpatialDataStoreRegistry.store.routesContaining(markerId: markerId) {
            try await removeWaypoint(from: route, markerId: markerId, using: spatialRead)
        }
    }
    
    static func updateWaypointInAllRoutes(markerId: String) throws {
        try SpatialDataStoreRegistry.store.routesContaining(markerId: markerId).forEach({
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

    static func updateWaypointInAllRoutes(markerId: String,
                                          using spatialRead: ReferenceReadContract) async throws {
        for route in SpatialDataStoreRegistry.store.routesContaining(markerId: markerId) {
            guard let first = route.waypoints.ordered.first else {
                continue
            }

            guard first.markerId == markerId else {
                continue
            }

            try await update(id: route.id,
                             name: route.name,
                             description: route.routeDescription,
                             waypoints: route.waypoints,
                             using: spatialRead)
        }
    }
    
    // MARK: Reverse a route
    
    /// Async-first reversed-route construction that hydrates first-waypoint coordinates
    /// through the read contract before route persistence.
    static func reversedRoute(from route: Route, using spatialRead: ReferenceReadContract) async -> Route? {
        guard !route.waypoints.isEmpty else { return nil }

        let orderedWaypoints = route.waypoints.ordered
        let reversedWaypoints = orderedWaypoints.reversed().enumerated().map { index, waypoint -> RouteWaypoint in
            var reversed = waypoint
            reversed.index = index
            return reversed
        }

        let firstWaypointCoordinate = await firstWaypointCoordinate(for: reversedWaypoints, using: spatialRead)
        let newName = GDLocalizedString("routes.reverse_name_format", route.name)
        return Route(name: newName,
                     description: route.routeDescription,
                     waypoints: reversedWaypoints,
                     firstWaypointCoordinate: firstWaypointCoordinate)
    }

    /// Checks whether two routes have the same ordered waypoints.
    static func isWaypointsEqual(_ route1: Route, _ route2: Route) -> Bool {
        let route1IDs = route1.waypoints.ordered.map { $0.markerId }
        let route2IDs = route2.waypoints.ordered.map { $0.markerId }
        return route1IDs == route2IDs
    }
    
    static func createReversedRoute(from route: Route, using spatialRead: ReferenceReadContract) async throws -> Route? {
        if let reversedId = route.reversedRouteId,
           let existing = Route.object(forPrimaryKey: reversedId) {
            return existing
        }

        guard var reversed = await reversedRoute(from: route, using: spatialRead) else {
            return nil
        }

        let nameResolution = resolvedReversedRouteName(for: reversed)
        if let existingRoute = nameResolution.existingRoute {
            return existingRoute
        }

        reversed.name = nameResolution.name

        try await add(reversed, using: spatialRead)
        try autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                throw RouteRealmError.databaseError
            }

            guard let persistedRoute = database.object(ofType: RealmRoute.self, forPrimaryKey: route.id),
                  let persistedReversed = database.object(ofType: RealmRoute.self, forPrimaryKey: reversed.id) else {
                return
            }

            try database.write {
                persistedRoute.linkReversedRoute(persistedReversed)
            }
        }

        return object(forPrimaryKey: reversed.id)
    }
}
