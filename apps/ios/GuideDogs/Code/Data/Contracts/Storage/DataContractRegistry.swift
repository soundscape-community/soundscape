//
//  DataContractRegistry.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributers.
//

import Foundation

@MainActor
enum DataContractRegistry {
    private static let defaultSpatialRead = RealmSpatialReadContract()
    private(set) static var spatialRead: SpatialReadContract = defaultSpatialRead

    static func configure(spatialRead: SpatialReadContract) {
        self.spatialRead = spatialRead
    }

    static func resetForTesting() {
        spatialRead = defaultSpatialRead
    }
}
