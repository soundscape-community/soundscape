// Copyright (c) Soundscape Community Contributers.

import Foundation
import SSGeo

public struct ReferenceEntity: Identifiable, Equatable, Sendable {
    public struct Keys {
        public static let entityId = "GDAReferenceEntityID"
    }

    public let id: String
    public let entityKey: String?
    public let lastUpdatedDate: Date?
    public let lastSelectedDate: Date?
    public let isNew: Bool
    public let isTemp: Bool
    public let coordinate: SSGeoCoordinate
    public let nickname: String?
    public let estimatedAddress: String?
    public let annotation: String?

    public init(
        id: String,
        entityKey: String?,
        lastUpdatedDate: Date?,
        lastSelectedDate: Date?,
        isNew: Bool,
        isTemp: Bool,
        coordinate: SSGeoCoordinate,
        nickname: String?,
        estimatedAddress: String?,
        annotation: String?
    ) {
        self.id = id
        self.entityKey = entityKey
        self.lastUpdatedDate = lastUpdatedDate
        self.lastSelectedDate = lastSelectedDate
        self.isNew = isNew
        self.isTemp = isTemp
        self.coordinate = coordinate
        self.nickname = nickname
        self.estimatedAddress = estimatedAddress
        self.annotation = annotation
    }

    public var latitude: Double {
        coordinate.latitude
    }

    public var longitude: Double {
        coordinate.longitude
    }
}
