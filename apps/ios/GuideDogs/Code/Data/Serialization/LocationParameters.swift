//
//  LocationParameters.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import SSDataContracts

typealias LocationParameters = SSDataContracts.LocationParameters

extension SSDataContracts.LocationParameters {
    typealias Completion = (Result<POI, Error>) -> Void

    @MainActor
    func fetchEntity(completion: @escaping Completion) {
        if let entity = entity {
            addOrUpdate(entity: entity, completion: completion)
        } else {
            let genericLocation = GenericLocation(lat: coordinate.latitude,
                                                  lon: coordinate.longitude,
                                                  name: name)
            completion(.success(genericLocation))
        }
    }

    @MainActor
    private func addOrUpdate(entity: EntityParameters, completion: @escaping Completion) {
        switch entity.source {
        case .osm:
            addOrUpdateOSMEntity(id: entity.lookupInformation, completion: completion)
        }
    }

    @MainActor
    private func addOrUpdateOSMEntity(id: String, completion: @escaping Completion) {
        Task { @MainActor in
            if let entity = await DataContractRegistry.spatialRead.poi(byKey: id) as? GDASpatialDataResultEntity {
                completion(.success(entity))
                return
            }

            do {
                let entity = try GDASpatialDataResultEntity.addOrUpdateSpatialCacheEntity(id: id, parameters: self)
                completion(.success(entity))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
