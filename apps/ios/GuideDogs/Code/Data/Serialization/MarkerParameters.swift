//
//  MarkerParameters.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import SSDataContracts

enum ImportMarkerError: Error {
    case invalidParameter
    case entityNotFound
    case unableToImportLocalEntity
    case failedToFetchMarker
}

typealias MarkerParameters = SSDataContracts.MarkerParameters

extension SSDataContracts.MarkerParameters {
    @MainActor
    init?(entity: POI, markerId: String?, estimatedAddress: String?, nickname: String?, annotation: String?, lastUpdatedDate: Date?) {
        let location: LocationParameters

        if let entity = entity as? GDASpatialDataResultEntity {
            let coordinate = CoordinateParameters(latitude: entity.centroidLatitude, longitude: entity.centroidLongitude)
            let entityParameters = EntityParameters(source: .osm, lookupInformation: entity.key)
            location = LocationParameters(name: entity.localizedName,
                                          address: entity.addressLine,
                                          coordinate: coordinate,
                                          entity: entityParameters)
        } else {
            let coordinate = CoordinateParameters(latitude: entity.centroidLatitude, longitude: entity.centroidLongitude)
            location = LocationParameters(name: entity.localizedName,
                                          address: nil,
                                          coordinate: coordinate,
                                          entity: nil)
        }

        self.init(id: markerId.flatMap { $0.isEmpty ? nil : $0 },
                  nickname: nickname.flatMap { $0.isEmpty ? nil : $0 },
                  annotation: annotation.flatMap { $0.isEmpty ? nil : $0 },
                  estimatedAddress: estimatedAddress.flatMap { $0.isEmpty ? nil : $0 },
                  lastUpdatedDate: lastUpdatedDate,
                  location: location)
    }

    @MainActor
    init?(marker: ReferenceEntity) {
        self.init(entity: marker.getPOI(),
                  markerId: marker.id,
                  estimatedAddress: marker.estimatedAddress,
                  nickname: marker.nickname,
                  annotation: marker.annotation,
                  lastUpdatedDate: marker.lastUpdatedDate)
    }

    @MainActor
    init?(markerId: String) {
        guard let marker = LocationDetailStoreAdapter.referenceEntity(byID: markerId) else {
            return nil
        }

        let locationCoordinate = CLLocationCoordinate2D(latitude: marker.latitude, longitude: marker.longitude)
        let locationMarker = LocationDetailStoreAdapter.referenceEntity(byLocation: locationCoordinate)
        let resolvedMarker = locationMarker ?? marker

        self.init(entity: resolvedMarker.getPOI(),
                  markerId: markerId,
                  estimatedAddress: resolvedMarker.estimatedAddress,
                  nickname: resolvedMarker.nickname,
                  annotation: resolvedMarker.annotation,
                  lastUpdatedDate: resolvedMarker.lastUpdatedDate)
    }

    @MainActor
    init?(entity: POI) {
        let matchedMarker: ReferenceEntity?
        if let location = entity as? GenericLocation {
            matchedMarker = LocationDetailStoreAdapter.referenceEntity(byLocation: location.location.coordinate)
        } else {
            matchedMarker = LocationDetailStoreAdapter.referenceEntity(byEntityKey: entity.key)
        }

        if let matchedMarker {
            let markerID = matchedMarker.isTemp ? nil : matchedMarker.id
            self.init(entity: entity,
                      markerId: markerID,
                      estimatedAddress: matchedMarker.estimatedAddress,
                      nickname: matchedMarker.nickname,
                      annotation: matchedMarker.annotation,
                      lastUpdatedDate: matchedMarker.lastUpdatedDate)
            return
        }

        self.init(entity: entity,
                  markerId: nil,
                  estimatedAddress: nil,
                  nickname: nil,
                  annotation: nil,
                  lastUpdatedDate: nil)
    }
}
