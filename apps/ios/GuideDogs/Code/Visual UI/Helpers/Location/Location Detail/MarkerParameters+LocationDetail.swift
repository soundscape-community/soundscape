//
//  MarkerParameters+LocationDetail.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation

@MainActor
extension MarkerParameters {
    init?(location detail: LocationDetail) {
        self.init(location: detail, fallbackMarkerID: nil)
    }

    private init?(location detail: LocationDetail, fallbackMarkerID: String?) {
        let entity: POI

        switch detail.source {
        case .entity:
            guard let cachedEntity = detail.entity else {
                return nil
            }

            entity = cachedEntity
        case .coordinate:
            entity = GenericLocation(lat: detail.location.coordinate.latitude,
                                     lon: detail.location.coordinate.longitude)
        case .designData(let location, _):
            entity = GenericLocation(lat: location.coordinate.latitude,
                                     lon: location.coordinate.longitude)
        case .screenshots(let poi):
            entity = poi
        }

        let markerId = detail.markerId ?? fallbackMarkerID
        self.init(entity: entity,
                  markerId: markerId,
                  estimatedAddress: detail.estimatedAddress,
                  nickname: detail.nickname,
                  annotation: detail.annotation,
                  lastUpdatedDate: detail.lastUpdatedDate)
    }

    typealias Completion = (Result<LocationDetail, Error>) -> Void

    func fetchMarker(completion: @escaping Completion) {
        // For OSM entities, add/update in cache before producing location detail.
        location.fetchEntity { result in
            Task { @MainActor in
                switch result {
                case .success(let entity):
                    let importedDetail = ImportedLocationDetail(nickname: nickname, annotation: annotation)
                    let locationDetail = LocationDetail(entity: entity, imported: importedDetail, telemetryContext: nil)
                    completion(.success(locationDetail))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
}
