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

protocol EntityParameterRepresentablePOI: POI {
    var entityParametersForSerialization: EntityParameters? { get }
}

extension SSDataContracts.MarkerParameters {
    @MainActor
    init?(entity: POI, markerId: String?, estimatedAddress: String?, nickname: String?, annotation: String?, lastUpdatedDate: Date?) {
        let coordinate = CoordinateParameters(latitude: entity.centroidLatitude, longitude: entity.centroidLongitude)
        let entityParameters = (entity as? EntityParameterRepresentablePOI)?.entityParametersForSerialization
        let address = entityParameters == nil ? nil : entity.addressLine
        let location = LocationParameters(name: entity.localizedName,
                                          address: address,
                                          coordinate: coordinate,
                                          entity: entityParameters)

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
    init?(markerId: String) async {
        await self.init(markerId: markerId, using: DataContractRegistry.spatialRead)
    }

    @MainActor
    init?(markerId: String, using spatialRead: ReferenceReadContract) async {
        guard let marker = await spatialRead.referenceEntity(byID: markerId) else {
            return nil
        }

        let locationMarker = await spatialRead.referenceEntity(byCoordinate: marker.coordinate)
        let resolvedMarker = locationMarker ?? marker

        self.init(entity: resolvedMarker.getPOI(),
                  markerId: markerId,
                  estimatedAddress: resolvedMarker.estimatedAddress,
                  nickname: resolvedMarker.nickname,
                  annotation: resolvedMarker.annotation,
                  lastUpdatedDate: resolvedMarker.lastUpdatedDate)
    }

    @MainActor
    init?(entity: POI) async {
        await self.init(entity: entity, using: DataContractRegistry.spatialRead)
    }

    @MainActor
    init?(entity: POI, using spatialRead: ReferenceReadContract) async {
        let matchedMarker: ReferenceEntity?
        if let location = entity as? GenericLocation {
            matchedMarker = await spatialRead.referenceEntity(byGenericLocation: location)
        } else {
            matchedMarker = await spatialRead.referenceEntity(byEntityKey: entity.key)
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
