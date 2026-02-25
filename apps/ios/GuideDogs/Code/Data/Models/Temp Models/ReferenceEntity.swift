//
//  ReferenceEntity.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributers.
//

import Foundation
import SSGeo

struct ReferenceEntity: Identifiable, Equatable {
    struct Keys {
        static let entityId = "GDAReferenceEntityID"
    }

    let id: String
    let entityKey: String?
    let lastUpdatedDate: Date?
    let lastSelectedDate: Date?
    let isNew: Bool
    let isTemp: Bool
    let coordinate: SSGeoCoordinate
    let nickname: String?
    let estimatedAddress: String?
    let annotation: String?

    var latitude: Double {
        coordinate.latitude
    }

    var longitude: Double {
        coordinate.longitude
    }
}
