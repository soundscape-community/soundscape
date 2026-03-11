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
        Task { @MainActor in
            do {
                let entity = try await DataContractRegistry.spatialMaintenanceWrite
                    .materializePointOfInterest(from: self)
                completion(.success(entity))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
