//
//  Route.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import RealmSwift
import CoreLocation
import SSGeo

private func detachedWaypoints<S: Sequence>(from waypoints: S) -> [RouteWaypoint] where S.Element == RouteWaypoint {
    var detached: [RouteWaypoint] = []
    detached.reserveCapacity(waypoints.underestimatedCount)
    for waypoint in waypoints {
        detached.append(waypoint)
    }
    return detached
}

private func detachedWaypoints<S: Sequence>(from waypoints: S) -> [RouteWaypoint] where S.Element == RealmRouteWaypoint {
    var detached: [RouteWaypoint] = []
    detached.reserveCapacity(waypoints.underestimatedCount)
    for waypoint in waypoints {
        detached.append(waypoint.domainModel)
    }
    return detached
}

private func realmWaypoints<S: Sequence>(from waypoints: S) -> List<RealmRouteWaypoint> where S.Element == RouteWaypoint {
    let persisted = List<RealmRouteWaypoint>()
    for waypoint in waypoints {
        persisted.append(waypoint.realmObject)
    }
    return persisted
}

@MainActor
enum RouteRuntime {
    static func currentUserLocation() -> CLLocation? {
        DataRuntimeProviderRegistry.providers.routeCurrentUserLocation()
    }

    static func activeRouteDatabaseID() -> String? {
        DataRuntimeProviderRegistry.providers.routeActiveRouteDatabaseID()
    }

    static func deactivateActiveBehavior() {
        DataRuntimeProviderRegistry.providers.routeDeactivateActiveBehavior()
    }

    static func storeRouteInCloud(_ route: Route) {
        DataRuntimeProviderRegistry.providers.routeStoreInCloud(route)
    }

    static func updateRouteInCloud(_ route: Route) {
        DataRuntimeProviderRegistry.providers.routeUpdateInCloud(route)
    }

    static func removeRouteFromCloud(_ route: Route) {
        DataRuntimeProviderRegistry.providers.routeRemoveFromCloud(route)
    }

    static func currentMotionActivityRawValue() -> String {
        DataRuntimeProviderRegistry.providers.routeCurrentMotionActivityRawValue()
    }
}

extension Notification.Name {
    static let routeAdded = Notification.Name("GDARouteAdded")
    static let routeUpdated = Notification.Name("GDARouteUpdated")
    static let routeDeleted = Notification.Name("GDARouteDeleted")
}

/*
 A route is an ordered collection of markers. Additional metadata for
 routes include name, description and various properties which track
 route usage (e.g., `createdDate`, `lastUpdatedDate`, `lastSelectedDate`)
 */
struct Route: Identifiable {

    // MARK: Constants

    struct Keys {
        static let id = "GDARouteID"
    }

    // MARK: Properties

    var id: String = UUID().uuidString
    var name: String = ""
    // `description` is a reserved name in multiple contexts, so prefix for consistency
    var routeDescription: String?
    var waypoints: [RouteWaypoint] = []
    // Save the location of the first waypoint to support fast queries
    // for nearby routes
    var firstWaypointLatitude: CLLocationDegrees?
    var firstWaypointLongitude: CLLocationDegrees?
    var isNew: Bool = true
    var createdDate: Date = Date()
    var lastUpdatedDate: Date = Date()
    // `lastSelectedDate` is updated when the user selects an action
    // (`RouteAction` - start, share, etc.) for the route
    var lastSelectedDate: Date = Date()
    var reversedRouteId: String?

    var firstWaypointLocation: CLLocation? {
        guard let latitude = firstWaypointLatitude, let longitude = firstWaypointLongitude else {
            return nil
        }

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        guard coordinate.isValidLocationCoordinate else {
            return nil
        }

        return CLLocation(coordinate)
    }

    @MainActor
    var isActive: Bool {
        RouteRuntime.activeRouteDatabaseID() == id
    }

    var realmObject: RealmRoute {
        RealmRoute(route: self)
    }

    // MARK: Initialization

    init() {}

    /**
     * Initializes a route for which all associated markers have been added to the Realm database
     *
     * - Parameters:
     *     - name: Name of the route, required
     *     - description: Description of the route, optional
     *     - waypoints: Array of waypoints - All waypoints are markers that exist in the Realm databse
     */
    @MainActor
    init(name: String, description: String?, waypoints: [RouteWaypoint]) {
        self.init(name: name,
                  description: description,
                  waypoints: waypoints,
                  firstWaypointCoordinate: nil)
    }

    @MainActor
    init(name: String, description: String?, waypoints: [RouteWaypoint], firstWaypointCoordinate: CLLocationCoordinate2D?) {
        self.name = name
        self.routeDescription = description
        self.waypoints = detachedWaypoints(from: waypoints)

        if let resolvedFirstWaypointCoordinate = firstWaypointCoordinate
            ?? Self.firstWaypointCoordinate(for: waypoints) {
            firstWaypointLatitude = resolvedFirstWaypointCoordinate.latitude
            firstWaypointLongitude = resolvedFirstWaypointCoordinate.longitude
        }
    }

    /**
     Only use this initializer when you made sure all the route waypoints (marker)
     were already imported to the database.
     */
    @MainActor
    init(from parameters: RouteParameters) {
        self.init(from: parameters, firstWaypointCoordinate: nil)
    }

    @MainActor
    init(from parameters: RouteParameters, firstWaypointCoordinate: CLLocationCoordinate2D?) {
        // Required Parameters
        id = parameters.id
        name = parameters.name
        routeDescription = parameters.routeDescription

        // Append waypoints
        let parameterWaypoints = parameters.waypoints.map { RouteWaypoint(from: $0) }
        waypoints = detachedWaypoints(from: parameterWaypoints)

        if let resolvedFirstWaypointCoordinate = firstWaypointCoordinate
            ?? Self.firstWaypointCoordinate(for: parameterWaypoints) {
            firstWaypointLatitude = resolvedFirstWaypointCoordinate.latitude
            firstWaypointLongitude = resolvedFirstWaypointCoordinate.longitude
        }

        // Optional Parameters

        if let parameterCreatedDate = parameters.createdDate {
            createdDate = parameterCreatedDate
        }

        if let parameterLastUpdatedDate = parameters.lastUpdatedDate {
            lastUpdatedDate = parameterLastUpdatedDate
        }

        if let parameterLastSelectedDate = parameters.lastSelectedDate {
            lastSelectedDate = parameterLastSelectedDate
        }
    }

    init(realmRoute: RealmRoute) {
        id = realmRoute.id
        name = realmRoute.name
        routeDescription = realmRoute.routeDescription
        waypoints = detachedWaypoints(from: realmRoute.waypoints)
        firstWaypointLatitude = realmRoute.firstWaypointLatitude
        firstWaypointLongitude = realmRoute.firstWaypointLongitude
        isNew = realmRoute.isNew
        createdDate = realmRoute.createdDate
        lastUpdatedDate = realmRoute.lastUpdatedDate
        lastSelectedDate = realmRoute.lastSelectedDate
        reversedRouteId = realmRoute.reversedRouteId
    }

    @MainActor
    static func firstWaypointCoordinate(for waypoints: [RouteWaypoint]) -> CLLocationCoordinate2D? {
        guard let first = waypoints.ordered.first else {
            return nil
        }

        if let markerCoordinate = markerCoordinate(forMarkerID: first.markerId) {
            return markerCoordinate
        }

        return first.asLocationDetail?.location.coordinate
    }

    @MainActor
    static func firstWaypointCoordinate(for waypoints: [RouteWaypoint], using spatialRead: ReferenceReadContract) async -> CLLocationCoordinate2D? {
        guard let first = waypoints.ordered.first else {
            return nil
        }

        if let markerCoordinate = await markerCoordinate(forMarkerID: first.markerId, using: spatialRead) {
            return markerCoordinate
        }

        return first.asLocationDetail?.location.coordinate
    }

    @MainActor
    static func firstWaypointCoordinate(for waypoints: [RouteWaypointParameters], using spatialRead: ReferenceReadContract) async -> CLLocationCoordinate2D? {
        guard let first = waypoints.min(by: { $0.index < $1.index }) else {
            return nil
        }

        if let markerCoordinate = first.marker?.location.coordinate {
            return CLLocationCoordinate2D(latitude: markerCoordinate.latitude,
                                          longitude: markerCoordinate.longitude)
        }

        return await markerCoordinate(forMarkerID: first.markerId, using: spatialRead)
    }

    @MainActor
    static func markerCoordinate(forMarkerID markerID: String) -> CLLocationCoordinate2D? {
        SpatialDataStoreRegistry.store.referenceEntityByKey(markerID)?.coordinate
    }

    @MainActor
    static func markerCoordinate(forMarkerID markerID: String, using spatialRead: ReferenceReadContract) async -> CLLocationCoordinate2D? {
        guard let marker = await spatialRead.referenceEntity(byID: markerID) else {
            return nil
        }

        return marker.coordinate.clCoordinate
    }
}

class RealmRoute: Object, ObjectKeyIdentifiable {

    // MARK: Properties

    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var name: String
    @Persisted var routeDescription: String?
    @Persisted var waypoints: List<RealmRouteWaypoint>
    @Persisted var firstWaypointLatitude: CLLocationDegrees?
    @Persisted var firstWaypointLongitude: CLLocationDegrees?
    @Persisted var isNew: Bool = true
    @Persisted var createdDate: Date = Date()
    @Persisted var lastUpdatedDate: Date = Date()
    @Persisted var lastSelectedDate: Date = Date()
    @Persisted var reversedRouteId: String?

    var firstWaypointLocation: CLLocation? {
        guard let latitude = firstWaypointLatitude, let longitude = firstWaypointLongitude else {
            return nil
        }

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        guard coordinate.isValidLocationCoordinate else {
            return nil
        }

        return CLLocation(coordinate)
    }

    @MainActor
    var isActive: Bool {
        RouteRuntime.activeRouteDatabaseID() == id
    }

    convenience init(route: Route) {
        let firstWaypointCoordinate: CLLocationCoordinate2D?
        if let latitude = route.firstWaypointLatitude, let longitude = route.firstWaypointLongitude {
            firstWaypointCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        } else {
            firstWaypointCoordinate = nil
        }

        self.init(route: route, firstWaypointCoordinate: firstWaypointCoordinate)
    }

    convenience init(route: Route, firstWaypointCoordinate: CLLocationCoordinate2D?) {
        self.init()
        applyRouteSnapshot(route, firstWaypointCoordinate: firstWaypointCoordinate)
    }
}

extension RealmRoute {
    var domainModel: Route {
        Route(realmRoute: self)
    }

    func replaceWaypoints(with waypoints: [RouteWaypoint]) {
        self.waypoints.removeAll()
        self.waypoints.append(objectsIn: waypoints.map { $0.realmObject })
    }

    func setFirstWaypointCoordinate(_ coordinate: CLLocationCoordinate2D?) {
        firstWaypointLatitude = coordinate?.latitude
        firstWaypointLongitude = coordinate?.longitude
    }

    func applyRouteSnapshot(_ route: Route, firstWaypointCoordinate: CLLocationCoordinate2D?) {
        id = route.id
        name = route.name
        routeDescription = route.routeDescription
        replaceWaypoints(with: route.waypoints)
        setFirstWaypointCoordinate(firstWaypointCoordinate)
        isNew = route.isNew
        createdDate = route.createdDate
        lastUpdatedDate = route.lastUpdatedDate
        lastSelectedDate = route.lastSelectedDate
        reversedRouteId = route.reversedRouteId
    }

    func applyRouteUpdate(name: String, routeDescription: String?, waypoints: [RouteWaypoint], firstWaypointCoordinate: CLLocationCoordinate2D?, at date: Date) {
        self.name = name
        self.routeDescription = routeDescription
        replaceWaypoints(with: waypoints)
        setFirstWaypointCoordinate(firstWaypointCoordinate)
        lastSelectedDate = date
        lastUpdatedDate = date
    }

    func linkReversedRoute(_ route: RealmRoute) {
        reversedRouteId = route.id
        route.reversedRouteId = id
    }

    func unlinkReversedRoute(_ route: RealmRoute) {
        reversedRouteId = nil
        route.reversedRouteId = nil
    }
}
