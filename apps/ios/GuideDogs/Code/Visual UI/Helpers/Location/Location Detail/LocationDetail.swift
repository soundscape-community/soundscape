//
//  LocationDetail.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import CocoaLumberjackSwift
import SwiftUI

@MainActor
struct LocationDetail {
    
    @MainActor
    enum Source: Equatable {
        
        case entity(id: String)
        case coordinate(at: CLLocation)
        case designData(at: CLLocation, address: String)
        case screenshots(poi: GenericLocation)
        
        var entity: POI? {
            if case .entity(let id) = self {
                return LocationDetailStoreAdapter.poi(byKey: id)
            } else if case .screenshots(let poi) = self {
                return poi
            }
            
            return nil
        }
        
        var name: String? {
            return entity?.localizedName
        }
        
        /// Determines whether the "Launch NaviLens" action should be shown
        var hasNaviLens: Bool {
            return entity?.superCategory == "navilens"
        }
        
        var address: String? {
            if case let .designData(_, address) = self {
                return address
            }
            
            return entity?.addressLine
        }
        
        var isCachingEnabled: Bool {
            // If the data source does not allow caching, return false
            // For OSM, return true
            return true
        }
        
        func closestLocation(from userLocation: CLLocation, useEntranceIfAvailable: Bool = true) -> CLLocation? {
            switch self {
            case .entity:
                return entity?.closestLocation(from: userLocation, useEntranceIfAvailable: useEntranceIfAvailable)
                
            case .coordinate(let location):
                return location
                
            case .designData(let location, _):
                return location
                
            case .screenshots(let poi):
                return poi.location
            }
        }
        
        static func == (lhs: Source, rhs: Source) -> Bool {
            switch lhs {
            case .entity(let lhsId):
                guard case .entity(let rhsId) = rhs else {
                    return false
                }
                
                return lhsId == rhsId
            case .coordinate(let lhsAt):
                guard case .coordinate(let rhsAt) = rhs else {
                    return false
                }
                
                return lhsAt.coordinate == rhsAt.coordinate
                
            case let .designData(lhsAt, lhsAddress):
                guard case let .designData(rhsAt, rhsAddress) = rhs else {
                    return false
                }
                
                return lhsAt.coordinate == rhsAt.coordinate && lhsAddress == rhsAddress
                
            case let .screenshots(lhsPoi):
                guard case let .screenshots(rhsPoi) = rhs else {
                    return false
                }
                
                return lhsPoi.location.coordinate == rhsPoi.location.coordinate && lhsPoi.name == rhsPoi.name && lhsPoi.addressLine == rhsPoi.addressLine
            }
        }
        
    }
    
    // MARK: Properties
    
    let source: Source
    let location: CLLocation
    let centerLocation: CLLocation
    let telemetryContext: String?
    
    // Estimated Properties
    private let estimated: EstimatedLocationDetail?
    // Imported Properties
    private let imported: ImportedLocationDetail?
    // Pre-resolved context for async-loaded details.
    private let resolvedEntity: POI?
    private let resolvedMarker: ReferenceEntity?
    
    // Marker Properties
    
    var markerId: String? {
        // Ignore temporary markers (e.g., beacons)
        guard let marker = marker, marker.isTemp == false else {
            return nil
        }
        
        return marker.id
    }
    
    var isMarker: Bool {
        return markerId != nil
    }

    var isNew: Bool {
        marker?.isNew ?? false
    }

    var lastUpdatedDate: Date? {
        marker?.lastUpdatedDate
    }
    
    var beaconId: String? {
        guard let destinationManager = UIRuntimeProviderRegistry.providers.uiSpatialDataContext()?.destinationManager else {
            return nil
        }

        switch source {
        case .entity(let id):
            guard let destinationKey = destinationManager.destinationKey,
                  isDestinationKeyMatch(id, destinationKey: destinationKey) else {
                return nil
            }

            return destinationKey

        case .screenshots(let poi):
            guard let destinationKey = destinationManager.destinationKey,
                  isDestinationKeyMatch(poi.key, destinationKey: destinationKey) else {
                return nil
            }

            return destinationKey

        case .coordinate, .designData:
            guard let marker = marker,
                  destinationManager.destinationKey == marker.id else {
                return nil
            }

            return marker.id
        }
    }
    
    var isBeacon: Bool {
        return beaconId != nil
    }
    
    var entity: POI? {
        resolvedEntity ?? source.entity
    }

    var hasNaviLens: Bool {
        entity?.superCategory == "navilens"
    }

    private var marker: ReferenceEntity? {
        resolvedMarker ?? referenceEntity(source: source, isTemp: nil)
    }

    private func isDestinationKeyMatch(_ key: String, destinationKey: String) -> Bool {
        guard destinationKey != key else {
            return true
        }

        return LocationDetailStoreAdapter.referenceEntity(byID: destinationKey)?.entityKey == key
    }
    
    // Name Properties
    
    var nickname: String? {
        if let imported = imported {
            // If a new nickname was imported (e.g. univeral link), use it
            // It is possible for this value to be `nil`
            return imported.nickname
        }
        
        if let nickname = marker?.nickname, nickname.isEmpty == false {
            return nickname
        }
        
        return nil
    }
    
    private var name: String? {
        if let name = nickname, name.isEmpty == false {
            return name
        }
        
        if let name = entity?.localizedName, name.isEmpty == false {
            return name
        }
        
        return nil
    }
    
    var displayName: String {
        if let name = name, name.isEmpty == false {
            return name
        }
        
        if let name = estimated?.name, name.isEmpty == false {
            // If a name does not exist, return an
            // estimated value
            return name
        }
        
        return GDLocalizedString("location")
    }
    
    var hasName: Bool {
        return name != nil
    }
    
    // Address Properties
    
    var estimatedAddress: String? {
        if let estimatedAddress = marker?.estimatedAddress, estimatedAddress.isEmpty == false {
            // If an estimated address has already been saved
            // with the marker, return it
            return estimatedAddress
        }
        
        if let estimatedAddress = estimated?.address, estimatedAddress.isEmpty == false {
            return estimatedAddress
        }
        
        return nil
    }
    
    private var address: String? {
        if case let .designData(_, designAddress) = source,
           designAddress.isEmpty == false {
            return designAddress
        }

        if let entityAddress = entity?.addressLine,
           entityAddress.isEmpty == false {
            return entityAddress
        }

        if let screenshotAddress = source.address, screenshotAddress.isEmpty == false {
            // `.screenshots` carries its POI directly on source.
            return screenshotAddress
        }
        
        if let address = estimatedAddress, address.isEmpty == false {
            return GDLocalizedString("directions.near_name", address)
        }
        
        return nil
    }
    
    var displayAddress: String {
        if let address = address {
            return address
        }
        
        // When an address is not provided, return a
        // default value
        return GDLocalizedString("location_detail.default.address")
    }

    private func referenceEntity(source: Source, isTemp: Bool?) -> ReferenceEntity? {
        let marker: ReferenceEntity?

        switch source {
        case .entity(let id):
            marker = LocationDetailStoreAdapter.referenceEntity(byEntityKey: id)
        case .coordinate(let location):
            marker = LocationDetailStoreAdapter.referenceEntity(byLocation: location.coordinate)
        case .designData:
            marker = nil
        case .screenshots(let poi):
            marker = LocationDetailStoreAdapter.referenceEntity(byEntityKey: poi.key)
        }

        guard let isTemp, let marker else {
            return marker
        }

        return marker.isTemp == isTemp ? marker : nil
    }
    
    var hasAddress: Bool {
        return address != nil
    }
    
    // Annotation Properties
    
    var annotation: String? {
        if let imported = imported {
            // If a new annotation was imported (e.g. univeral link), use it
            // It is possible for this value to be `nil`
            return imported.annotation
        }
        
        if let annotation = marker?.annotation, annotation.isEmpty == false {
            return annotation
        }
        
        return nil
    }
    
    var displayAnnotation: String {
        if let annotation = annotation {
            return annotation
        }
        
        // When an annotation is not provided, return a
        // default value
        return GDLocalizedString("location_detail.default.annotation")
    }
    
    // MARK: Waypoint Properties
    
    var departureCallout: String? {
        return imported?.departureCallout
    }
    
    var arrivalCallout: String? {
        return imported?.arrivalCallout
    }
    
    var images: [ActivityWaypointImage]? {
        return imported?.images
    }
    
    var hasImages: Bool {
        guard let images = images else {
            return false
        }
        
        return images.count > 0
    }
    
    var audio: [ActivityWaypointAudioClip]? {
        return imported?.audio
    }
    
    var hasAudio: Bool {
        guard let audio = audio else {
            return false
        }
        
        return audio.count > 0
    }
    
    // MARK: Private Initializers
    
    private init(value: LocationDetail, newLocation: CLLocation) {
        let source = value.source
        let centerLocation = value.centerLocation
        let estimated = value.estimated
        let imported = value.imported
        let telemetryContext = value.telemetryContext
        let resolvedEntity = value.resolvedEntity
        let resolvedMarker = value.resolvedMarker
        
        self.init(source: source,
                  location: newLocation,
                  centerLocation: centerLocation,
                  estimated: estimated,
                  imported: imported,
                  telemetryContext: telemetryContext,
                  resolvedEntity: resolvedEntity,
                  resolvedMarker: resolvedMarker)
    }
    
    private init(value: LocationDetail, estimated: EstimatedLocationDetail, telemetryContext: String?) {
        let source = value.source
        let location = value.location
        let centerLocation = value.centerLocation
        let imported = value.imported
        let resolvedEntity = value.resolvedEntity
        let resolvedMarker = value.resolvedMarker
        
        self.init(source: source,
                  location: location,
                  centerLocation: centerLocation,
                  estimated: estimated,
                  imported: imported,
                  telemetryContext: telemetryContext,
                  resolvedEntity: resolvedEntity,
                  resolvedMarker: resolvedMarker)
    }
    
    private init(source: Source,
                 location: CLLocation,
                 centerLocation: CLLocation,
                 estimated: EstimatedLocationDetail?,
                 imported: ImportedLocationDetail?,
                 telemetryContext: String?,
                 resolvedEntity: POI? = nil,
                 resolvedMarker: ReferenceEntity? = nil) {
        self.source = source
        self.location = location
        self.centerLocation = centerLocation
        self.estimated = estimated
        self.imported = imported
        self.telemetryContext = telemetryContext
        self.resolvedEntity = resolvedEntity
        self.resolvedMarker = resolvedMarker
    }
    
    // MARK: Realm

    func updateLastSelectedDate() {
        Task { @MainActor in
            do {
                if let marker = self.marker {
                    try await DataContractRegistry.spatialWrite.markReferenceEntitySelected(id: marker.id)
                } else if let entity = self.entity as? SelectablePOI {
                    try await DataContractRegistry.spatialWrite.markPointOfInterestSelected(entityKey: entity.key)
                }
            } catch {
                DDLogError("Failed to update last selected date in Realm")
            }
        }
    }
    
}

// MARK: Public Initializers

extension LocationDetail {
    
    private init(entity: POI,
                 imported: ImportedLocationDetail? = nil,
                 telemetryContext: String? = nil,
                 resolvedMarker: ReferenceEntity?) {
        if let entity = entity as? GenericLocation {
            let source: Source = .coordinate(at: entity.location)
            self.init(source: source,
                      location: entity.location,
                      centerLocation: entity.location,
                      estimated: nil,
                      imported: imported,
                      telemetryContext: telemetryContext,
                      resolvedEntity: entity,
                      resolvedMarker: resolvedMarker)
        } else {
            let source: Source = .entity(id: entity.key)
            let centerLocation = entity.centroidLocation
            let location: CLLocation

            if let userLocation = UIRuntimeProviderRegistry.providers.uiCurrentUserLocation() {
                location = entity.closestLocation(from: userLocation)
            } else {
                location = entity.centroidLocation
            }

            self.init(source: source,
                      location: location,
                      centerLocation: centerLocation,
                      estimated: nil,
                      imported: imported,
                      telemetryContext: telemetryContext,
                      resolvedEntity: entity,
                      resolvedMarker: resolvedMarker)
        }
    }

    init(marker: ReferenceEntity, imported: ImportedLocationDetail? = nil, telemetryContext: String? = nil) {
        self.init(entity: marker.getPOI(),
                  imported: imported,
                  telemetryContext: telemetryContext,
                  resolvedMarker: marker)
    }

    @available(*, deprecated, message: "Use LocationDetail.load(markerId:imported:telemetryContext:) for persisted marker lookups.")
    init?(markerId: String, imported: ImportedLocationDetail? = nil, telemetryContext: String? = nil) {
        guard let marker = LocationDetailStoreAdapter.referenceEntity(byID: markerId) else {
            return nil
        }
        
        self.init(marker: marker, imported: imported, telemetryContext: telemetryContext)
    }
    
    init(location: CLLocation, imported: ImportedLocationDetail? = nil, telemetryContext: String? = nil) {
        let source: Source = .coordinate(at: location)
        self.init(source: source, location: location, centerLocation: location, estimated: nil, imported: imported, telemetryContext: telemetryContext)
    }
    
    init(entity: POI, imported: ImportedLocationDetail? = nil, telemetryContext: String? = nil) {
        self.init(entity: entity,
                  imported: imported,
                  telemetryContext: telemetryContext,
                  resolvedMarker: nil)
    }
    
    @available(*, deprecated, message: "Use LocationDetail.load(entityId:imported:telemetryContext:) for persisted entity lookups.")
    init?(entityId: String, imported: ImportedLocationDetail? = nil, telemetryContext: String? = nil) {
        guard let entity = LocationDetailStoreAdapter.poi(byKey: entityId) else {
            return nil
        }
        
        self.init(entity: entity, imported: imported, telemetryContext: telemetryContext)
    }
    
    init?(designTimeSource: LocationDetail.Source, imported: ImportedLocationDetail? = nil, telemetryContext: String? = nil) {
        guard case let .designData(location, _) = designTimeSource else {
            return nil
        }
        
        self.init(source: designTimeSource, location: location, centerLocation: location, estimated: nil, imported: imported, telemetryContext: telemetryContext)
    }
    
    /// Used for updating an existing marker to a new location. Preserves the name and annotation from the original location, but the address
    /// should be fetched again using `fetchNameAndAddressIfNeeded(for:completion:)`
    ///
    /// - Parameters:
    ///   - original: The original `LocationDetail`
    ///   - location: The new location of the marker
    init(_ original: LocationDetail, withUpdatedLocation location: CLLocation) {
        let source: LocationDetail.Source = .coordinate(at: location)
        let imported = ImportedLocationDetail(nickname: original.name, annotation: original.annotation)
        let telemetryContext = original.telemetryContext
        
        self.init(source: source, location: location, centerLocation: location, estimated: nil, imported: imported, telemetryContext: telemetryContext)
    }
    
    static func fetchNameAndAddressIfNeeded(for value: LocationDetail, completion: @escaping (LocationDetail) -> Void) {
        guard value.name == nil || value.address == nil else {
            // `name` and `address` are already
            // provided
            completion(value)
            return
        }
        
        EstimatedLocationDetail.make(for: value) { (estimatedValue) in
            let newValue = LocationDetail(value: value, estimated: estimatedValue, telemetryContext: value.telemetryContext)
            completion(newValue)
        }
    }
    
    static func updateLocationIfNeeded(for value: LocationDetail) -> LocationDetail {
        guard let entity = value.entity else {
            // no-op
            return value
        }
        
        guard let userLocation = UIRuntimeProviderRegistry.providers.uiCurrentUserLocation() else {
            // no-op
            return value
        }
        
        let newLocation = entity.closestLocation(from: userLocation)
        return LocationDetail(value: value, newLocation: newLocation)
    }

    static func load(markerId: String,
                     imported: ImportedLocationDetail? = nil,
                     telemetryContext: String? = nil) async -> LocationDetail? {
        guard let marker = await DataContractRegistry.spatialRead.referenceEntity(byID: markerId) else {
            return nil
        }

        return LocationDetail(marker: marker,
                              imported: imported,
                              telemetryContext: telemetryContext)
    }

    static func load(entityId: String,
                     imported: ImportedLocationDetail? = nil,
                     telemetryContext: String? = nil) async -> LocationDetail? {
        guard let entity = await DataContractRegistry.spatialRead.poi(byKey: entityId) else {
            return nil
        }

        return LocationDetail(entity: entity,
                              imported: imported,
                              telemetryContext: telemetryContext)
    }

    static func load(entity: POI,
                     imported: ImportedLocationDetail? = nil,
                     telemetryContext: String? = nil) async -> LocationDetail {
        let resolvedMarker: ReferenceEntity?

        if let genericLocation = entity as? GenericLocation {
            resolvedMarker = await DataContractRegistry.spatialRead.referenceEntity(byGenericLocation: genericLocation)
        } else {
            resolvedMarker = await DataContractRegistry.spatialRead.referenceEntity(byEntityKey: entity.key)
        }

        return LocationDetail(entity: entity,
                              imported: imported,
                              telemetryContext: telemetryContext,
                              resolvedMarker: resolvedMarker)
    }

    static func load(location: CLLocation,
                     imported: ImportedLocationDetail? = nil,
                     telemetryContext: String? = nil) async -> LocationDetail {
        let marker = await DataContractRegistry.spatialRead.referenceEntity(byCoordinate: location.coordinate.ssGeoCoordinate)
        let source: Source = .coordinate(at: location)

        return LocationDetail(source: source,
                              location: location,
                              centerLocation: location,
                              estimated: nil,
                              imported: imported,
                              telemetryContext: telemetryContext,
                              resolvedMarker: marker)
    }
    
}
