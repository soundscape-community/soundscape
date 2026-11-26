// Copyright (c) Microsoft Corporation.
// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import Foundation
import CoreLocation
import SSData

extension Route {
    static func object(forPrimaryKey key: String) -> Route? {
        SpatialDataCache.routeByKey(key)
    }

    static func objectKeys(sortedBy: SortStyle) -> [String] {
        let routes = StorageContext.shared.routes
        switch sortedBy {
        case .alphanumeric:
            return routes.sorted { $0.name < $1.name }.map(\.id)
        case .distance:
            let location = AppContext.shared.geolocationManager.location ?? CLLocation(latitude: 0, longitude: 0)
            return routes.map { route -> (String, CLLocationDistance) in
                let start = route.waypoints.first.flatMap { SpatialDataCache.referenceEntityByKey($0.markerId) }
                return (route.id, start?.distanceToClosestLocation(from: location) ?? .greatestFiniteMagnitude)
            }.sorted { $0.1 < $1.1 }.map { $0.0 }
        }
    }

    @MainActor
    static func add(_ route: Route, context: String? = nil) async throws {
        let existing = object(forPrimaryKey: route.id)
        var markers: [Marker] = []
        var resolved: [Waypoint] = []
        for waypoint in route.waypoints.ordered {
            if let detail = waypoint.importedDetail {
                let reference: ReferenceEntity
                if let stored = SpatialDataCache.referenceEntity(source: detail.source, isTemp: nil) {
                    reference = ReferenceEntity(stored: stored.stored)
                    reference.nickname = detail.nickname
                    if let address = detail.estimatedAddress { reference.estimatedAddress = address }
                    reference.annotation = detail.annotation
                    if reference.isTemp { reference.isNew = true }
                    reference.isTemp = false
                    reference.lastUpdatedDate = Date()
                } else if case .entity = detail.source, let poi = detail.resolvedPOI {
                    reference = ReferenceEntity.makeReference(for: poi, nickname: detail.nickname,
                                                              address: detail.estimatedAddress, annotation: detail.annotation,
                                                              preservePlace: SpatialDataCache.searchMapByKey(poi.key) == nil)
                } else {
                    reference = ReferenceEntity(coordinate: detail.location.coordinate, name: detail.nickname ?? detail.displayName,
                                                estimatedAddress: detail.estimatedAddress ?? detail.resolvedPOI?.addressLine,
                                                annotation: detail.annotation)
                }
                let match = markers.first { candidate in
                    if let key = reference.entityKey { return candidate.entityKey == key }
                    return candidate.entityKey == nil && candidate.latitude == reference.latitude && candidate.longitude == reference.longitude
                }
                if match == nil { markers.append(reference.stored) }
                resolved.append(Waypoint(markerId: match?.id ?? reference.id, index: waypoint.index))
            } else {
                resolved.append(waypoint.stored)
            }
        }
        var saved = route.saved
        saved.waypoints = resolved
        if existing != nil {
            saved.lastUpdatedDate = Date()
            saved.lastSelectedDate = saved.lastUpdatedDate
        }
        let pendingRoute = saved
        let pendingMarkers = markers
        try await StorageContext.shared.writeAsync { try $0.save(route: pendingRoute, importing: pendingMarkers) }
        route.waypoints = resolved.map { RouteWaypoint(stored: $0) }
        if existing == nil {
            NotificationCenter.default.post(name: .routeAdded, object: self, userInfo: [Keys.id: route.id])
            GDATelemetry.track("routes.added", with: ["context": context ?? "none",
                                                     "activity": AppContext.shared.motionActivityContext.currentActivity.rawValue])
        } else {
            notifyUpdated(route.id)
        }
    }

    static func delete(_ id: String) throws {
        let wasActive = object(forPrimaryKey: id)?.isActive == true
        try StorageContext.shared.write { try $0.deleteRoute(id) }
        if wasActive { AppContext.shared.eventProcessor.deactivateCustom() }
        notifyDeleted(id)
    }

    static func notifyDeleted(_ id: String) {
        NotificationCenter.default.post(name: .routeDeleted, object: self, userInfo: [Keys.id: id])
    }

    static func notifyUpdated(_ id: String) {
        if object(forPrimaryKey: id)?.isActive == true {
            AppContext.shared.eventProcessor.deactivateCustom()
        }
        NotificationCenter.default.post(name: .routeUpdated, object: self, userInfo: [Keys.id: id])
    }

    static func updateLastSelectedDate(id: String, _ lastSelectedDate: Date = Date()) throws {
        try StorageContext.shared.write { try $0.selectRoute(id, at: lastSelectedDate) }
        NotificationCenter.default.post(name: .routeUpdated, object: self, userInfo: [Keys.id: id])
    }

    @MainActor
    static func update(id: String, name: String, description: String?, waypoints: [LocationDetail]) async throws {
        guard let route = object(forPrimaryKey: id) else { throw UserDataError.missingRoute(id) }
        route.name = name
        route.routeDescription = description
        route.waypoints = waypoints.enumerated().compactMap { RouteWaypoint(index: $0, locationDetail: $1) }
        try await add(route)
    }

    static func createReversedRoute(from route: Route) throws -> Route? {
        let name = GDLocalizedString("routes.reverse_name_format", route.name)
        let result = try StorageContext.shared.write { try $0.reverseRoute(route.id, suggestedName: name) }
        guard let saved = result.0 else { return nil }
        if result.created {
            NotificationCenter.default.post(name: .routeAdded, object: self, userInfo: [Keys.id: saved.id])
        }
        return Route(saved: saved)
    }
}
