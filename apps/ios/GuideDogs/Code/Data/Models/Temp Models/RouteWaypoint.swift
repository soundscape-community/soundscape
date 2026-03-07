//
//  RouteWaypoint.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributers.
//

import Foundation
import SSDataDomain
import SSGeo

/*
 Represents the waypoints belonging to a route.

 Each waypoint in the `Route` object is represented by
 an existing `RealmReferenceEntity` (e.g., `markerId`) and an
 index that reflects the waypoint's ordering within the
 route.
 */
typealias RouteWaypoint = SSDataDomain.RouteWaypoint

@MainActor
extension RouteWaypoint {
    // This value should never be `nil`
    var asLocationDetail: LocationDetail? {
        // If there is imported marker data, return it.
        if let importedReferenceEntity {
            return LocationDetail(marker: importedReferenceEntity)
        }

        // Otherwise, return Realm data.
        return LocationDetail(markerId: markerId)
    }

    func locationDetail(using spatialRead: ReferenceReadContract) async -> LocationDetail? {
        if let importedReferenceEntity {
            return LocationDetail(marker: importedReferenceEntity)
        }

        // Preserve existing behavior for persisted markers that can still be resolved
        // through the current sync compatibility seam.
        if let persistedLocationDetail = LocationDetail(markerId: markerId) {
            return persistedLocationDetail
        }

        guard let marker = await spatialRead.referenceEntity(byID: markerId) else {
            return nil
        }

        return LocationDetail(marker: marker)
    }

    /**
     * Initializes a waypoint from a marker that exists in the Realm database.
     *
     * - Parameters:
     *     - index: Index of the waypoint
     *     - markerId: ID for a marker that exists in Realm database
     */
    init?(index: Int, markerId: String) {
        guard LocationDetail(markerId: markerId) != nil else {
            // Marker does not exist
            return nil
        }

        self.init(index: index, markerId: markerId, importedReferenceEntity: nil)
    }

    /**
     * Initializes a waypoint from a marker that exists in the Realm database.
     *
     * - Parameters:
     *     - index: Index of the waypoint
     *     - locationDetail: Data for a marker that exists in Realm database
     */
    init?(index: Int, locationDetail: LocationDetail) {
        guard let markerId = locationDetail.markerId else {
            // Location is not a marker
            return nil
        }

        self.init(index: index, markerId: markerId, importedReferenceEntity: nil)
    }

    /**
     * Initializes a waypoint from a marker that is being imported from a URL resource (e.g.,
     * sharing activity) and has not been added to the Realm database.
     *
     * Initializer should only be called after fetching the associated marker data via `RouteParametersHandler`!
     *
     * - Parameters:
     *     - index: Index of the waypoint
     *     - markerId: ID for imported marker
     *     - importedLocationDetail: Data for marker that is being imported
     */
    init(index: Int, markerId: String, importedLocationDetail: LocationDetail) {
        self.init(index: index,
                  markerId: markerId,
                  importedReferenceEntity: Self.importedReferenceEntity(from: importedLocationDetail,
                                                                        markerId: markerId))
    }

    static func validated(index: Int, markerId: String, using spatialRead: ReferenceReadContract) async -> RouteWaypoint? {
        guard await spatialRead.referenceEntity(byID: markerId) != nil else {
            return nil
        }

        return RouteWaypoint(index: index,
                             markerId: markerId,
                             importedReferenceEntity: nil)
    }

    init(from parameters: RouteWaypointParameters) {
        self.init(index: parameters.index,
                  markerId: parameters.markerId,
                  importedReferenceEntity: nil)
    }

    private static func importedReferenceEntity(from detail: LocationDetail, markerId: String) -> ReferenceEntity {
        let coordinate = SSGeoCoordinate(latitude: detail.location.coordinate.latitude,
                                         longitude: detail.location.coordinate.longitude)
        return ReferenceEntity(id: markerId,
                               entityKey: detail.entity?.key,
                               lastUpdatedDate: detail.lastUpdatedDate,
                               lastSelectedDate: nil,
                               isNew: detail.isNew,
                               isTemp: true,
                               coordinate: coordinate,
                               nickname: detail.nickname,
                               estimatedAddress: detail.estimatedAddress,
                               annotation: detail.annotation)
    }
}

@MainActor
extension Array where Element == RouteWaypoint {
    var asLocationDetail: [LocationDetail] {
        compactMap({ $0.asLocationDetail })
    }

    func locationDetails(using spatialRead: ReferenceReadContract) async -> [LocationDetail] {
        var details: [LocationDetail] = []

        for waypoint in self {
            guard let detail = await waypoint.locationDetail(using: spatialRead) else {
                continue
            }

            details.append(detail)
        }

        return details
    }
}
