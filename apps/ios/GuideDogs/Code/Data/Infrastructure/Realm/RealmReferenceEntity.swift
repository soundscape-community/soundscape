//
//  RealmReferenceEntity.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import RealmSwift
import SSGeo

extension ReferenceEntity {
    @MainActor
    init(realmEntity: RealmReferenceEntity) {
        self.init(id: realmEntity.id,
                  entityKey: realmEntity.entityKey,
                  lastUpdatedDate: realmEntity.lastUpdatedDate,
                  lastSelectedDate: realmEntity.lastSelectedDate,
                  isNew: realmEntity.isNew,
                  isTemp: realmEntity.isTemp,
                  coordinate: realmEntity.geoCoordinate,
                  nickname: realmEntity.nickname,
                  estimatedAddress: realmEntity.estimatedAddress,
                  annotation: realmEntity.annotation)
    }
}

@MainActor
extension ReferenceEntity {
    private var poi: POI? {
        guard let entityKey else {
            return nil
        }

        return SpatialDataCache.searchByKey(key: entityKey)
    }

    var name: String {
        nickname ?? givenLocalizedName
    }

    var givenLocalizedName: String {
        getPOI().localizedName
    }

    var address: String {
        let estimated = estimatedAddress != nil
        ? GDLocalizedString("directions.near_name", estimatedAddress!)
        : GDLocalizedString("directions.unknown_address")

        guard entityKey != nil else {
            return estimated
        }

        guard let entity = poi else {
            return estimatedAddress ?? GDLocalizedString("directions.unknown_address")
        }

        return entity.addressLine ?? estimated
    }

    var displayAddress: String {
        if name != givenLocalizedName
            && !address.localizedCaseInsensitiveContains(givenLocalizedName)
            && !(getPOI() is Address) {
            return "\(givenLocalizedName)\n\(address)"
        }

        return address
    }

    func distanceToClosestLocation(from location: CLLocation) -> CLLocationDistance {
        if let poi {
            return poi.distanceToClosestLocation(from: location)
        }

        return SSGeoMath.distanceMeters(from: coordinate, to: location.coordinate.ssGeoCoordinate)
    }

    func bearingToClosestLocation(from location: CLLocation) -> CLLocationDirection {
        if let poi {
            return poi.bearingToClosestLocation(from: location)
        }

        return SSGeoMath.initialBearingDegrees(from: location.coordinate.ssGeoCoordinate, to: coordinate)
    }

    func closestLocation(from location: CLLocation) -> CLLocation {
        if let poi {
            return poi.closestLocation(from: location, useEntranceIfAvailable: true)
        }

        return coordinate.clLocation
    }

    func getPOI() -> POI {
        poi ?? GenericLocation(ref: self)
    }
}

@MainActor
enum ReferenceEntityRuntime {
    enum AddedTelemetryType: String {
        case address
        case poi
        case genericLocation = "generic_location"
    }

    struct Integration {
        var updateReferenceInCloud: (MarkerParameters) -> Void
        var removeReferenceFromCloud: (String) -> Void
        var didAddReferenceEntity: (String, AddedTelemetryType?, Bool, String?, Bool) -> Void
        var didUpdateReferenceEntity: (String, Bool, String?) -> Void
        var notifyReferenceEntityUpdated: (String) -> Void
        var notifyReferenceEntityRemoved: (String) -> Void
        var didRemoveReferenceEntity: (String) -> Void
        var setDestinationTemporaryIfMatchingID: (String) throws -> Bool
        var clearDestinationForCacheReset: () async throws -> Void
        var removeCalloutHistoryForMarkerID: (String) -> Void
        var processEvent: (Event) -> Void

        static let unconfigured = Self(
            updateReferenceInCloud: { _ in
                ReferenceEntityRuntime.debugAssertUnconfigured(#function)
            },
            removeReferenceFromCloud: { _ in
                ReferenceEntityRuntime.debugAssertUnconfigured(#function)
            },
            didAddReferenceEntity: { _, _, _, _, _ in
                ReferenceEntityRuntime.debugAssertUnconfigured(#function)
            },
            didUpdateReferenceEntity: { _, _, _ in
                ReferenceEntityRuntime.debugAssertUnconfigured(#function)
            },
            notifyReferenceEntityUpdated: { _ in
                ReferenceEntityRuntime.debugAssertUnconfigured(#function)
            },
            notifyReferenceEntityRemoved: { _ in
                ReferenceEntityRuntime.debugAssertUnconfigured(#function)
            },
            didRemoveReferenceEntity: { _ in
                ReferenceEntityRuntime.debugAssertUnconfigured(#function)
            },
            setDestinationTemporaryIfMatchingID: { _ in
                ReferenceEntityRuntime.debugAssertUnconfigured(#function)
                return false
            },
            clearDestinationForCacheReset: {
                ReferenceEntityRuntime.debugAssertUnconfigured(#function)
            },
            removeCalloutHistoryForMarkerID: { _ in
                ReferenceEntityRuntime.debugAssertUnconfigured(#function)
            },
            processEvent: { _ in
                ReferenceEntityRuntime.debugAssertUnconfigured(#function)
            }
        )
    }

    private static var integration = Integration.unconfigured

    static func configure(with integration: Integration) {
        self.integration = integration
    }

    static func resetForTesting() {
        integration = .unconfigured
    }

    static func updateReferenceInCloud(_ markerParameters: MarkerParameters) {
        integration.updateReferenceInCloud(markerParameters)
    }

    static func removeReferenceFromCloud(markerID: String) {
        integration.removeReferenceFromCloud(markerID)
    }

    static func didAddReferenceEntity(id: String,
                                      type: AddedTelemetryType?,
                                      includesAnnotation: Bool,
                                      context: String?,
                                      notify: Bool) {
        integration.didAddReferenceEntity(id, type, includesAnnotation, context, notify)
    }

    static func didUpdateReferenceEntity(id: String,
                                         includesAnnotation: Bool,
                                         context: String?) {
        integration.didUpdateReferenceEntity(id, includesAnnotation, context)
    }

    static func notifyReferenceEntityUpdated(id: String) {
        integration.notifyReferenceEntityUpdated(id)
    }

    static func notifyReferenceEntityRemoved(id: String) {
        integration.notifyReferenceEntityRemoved(id)
    }

    static func didRemoveReferenceEntity(id: String) {
        integration.didRemoveReferenceEntity(id)
    }

    static func setDestinationTemporaryIfMatchingID(_ id: String) throws -> Bool {
        try integration.setDestinationTemporaryIfMatchingID(id)
    }

    static func clearDestinationForCacheReset() async throws {
        try await integration.clearDestinationForCacheReset()
    }

    static func removeCalloutHistoryForMarkerID(_ markerID: String) {
        integration.removeCalloutHistoryForMarkerID(markerID)
    }

    static func processEvent(_ event: Event) {
        integration.processEvent(event)
    }

    nonisolated private static func debugAssertUnconfigured(_ method: StaticString) {
#if DEBUG
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            assertionFailure("ReferenceEntityRuntime is unconfigured when calling \(method)")
        }
#endif
    }
}

enum ReferenceEntityError: Error {
    case entityKeyDoesNotExist
    case entityDoesNotExist
    case cannotCacheEntity
    case cannotAddMarker
}

extension Notification.Name {
    static let markerAdded = Notification.Name("GDAMarkerAdded")
    static let markerRemoved = Notification.Name("GDAMarkerRemoved")
    static let markerUpdated = Notification.Name("GDAMarkerUpdated")
}

@MainActor
class RealmReferenceEntity: Object, ObjectKeyIdentifiable {
    // MARK: Constants
    
    struct Keys {
        static let entityId = ReferenceEntity.Keys.entityId
    }
    
    // MARK: Properties

    @Persisted(primaryKey: true) var id: String = UUID().uuidString // Primary key
    @Persisted var entityKey: String?
    @Persisted var lastUpdatedDate: Date?
    @Persisted var lastSelectedDate: Date? = Date()
    @Persisted var isNew: Bool = true
    @Persisted var isTemp: Bool = true
    
    @Persisted var latitude: CLLocationDegrees = 0.0
    @Persisted var longitude: CLLocationDegrees = 0.0
    
    @Persisted var nickname: String?
    @Persisted var estimatedAddress: String?
    @Persisted var annotation: String?
    
    private lazy var _poi: POI? = {
        guard let key = entityKey else {
            return nil
        }

        return SpatialDataCache.searchByKey(key: key)
    }()
    
    // MARK: Computed Properties
    
    /// CLLocationCoordinate2D for the referenced entity
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Portable coordinate payload for cross-platform boundaries.
    var geoCoordinate: SSGeoCoordinate {
        coordinate.ssGeoCoordinate
    }
    
    /// A computed property that returns the "preferred" name of the POI. If the entity
    /// has a nickname, that will be returned, otherwise the given name of the entity
    /// will be returned
    var name: String {
        if let nickname = nickname {
            return nickname
        }
        
        return givenLocalizedName
    }
    
    /// The "given" name of an entity is the name attached to the underlying POI object
    var givenLocalizedName: String {
        return getPOI().localizedName
    }
    
    /// The address of an entity returns the known address of the underlying POI if
    /// it exists, or the estimated address of the reference otherwise.
    var address: String {
        let estimated = estimatedAddress != nil ? GDLocalizedString("directions.near_name", estimatedAddress!) : GDLocalizedString("directions.unknown_address")
        
        if entityKey == nil {
            return estimated
        }
        
        // If the reference entity has an entity key, but we can't find that entity, it is most likely an address
        // object that was somehow deleted. In that case, return the estimated address as if it were the actual address...
        guard let entity = _poi else {
            return estimatedAddress != nil ? estimatedAddress! : GDLocalizedString("directions.unknown_address")
        }
        
        return entity.addressLine ?? estimated
    }
    
    /// Address string that should be used when displaying this reference entity on screen
    var displayAddress: String {
        // If the nickname is different from the given name (and the underlying POI isn't an Address), prepend the address with the given name.
        if name != givenLocalizedName && !address.localizedCaseInsensitiveContains(givenLocalizedName) && !(getPOI() is Address) {
            return "\(givenLocalizedName)\n\(address)"
        }
        
        return address
    }
    
    // MARK: Initialization
    
    /// Reference Entity initializer.
    ///
    /// - Parameters:
    ///   - entityKey: Primary key of the backing POI for this reference entity
    ///   - coordinate: The lat/lon of the reference entity. This parameter is used for re-caching the backing POI information if the cached data is deleted but the reference entity is not.
    ///   - name: Optional nickname for the reference entity
    convenience init(coordinate: CLLocationCoordinate2D, entityKey: String? = nil, name: String? = nil, estimatedAddress: String? = nil, annotation: String? = nil, temp: Bool = false) {
        self.init()
        
        // Set entity
        self.entityKey = entityKey
        
        // Set location info for re-caching
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        
        // Set the nickname
        if let name = name, name.isEmpty == false {
            nickname = name
        } else {
            nickname = nil
        }
        
        // Set the estimated address from the generic location
        if let estimatedAddress = estimatedAddress, estimatedAddress.isEmpty == false {
            self.estimatedAddress = estimatedAddress
        } else {
            self.estimatedAddress = nil
        }
        
        // Set the annotation
        if let annotation = annotation, annotation.isEmpty == false {
            self.annotation = annotation
        } else {
            self.annotation = nil
        }
        
        // Set temporary status
        isTemp = temp
    }

    convenience init(coordinate: SSGeoCoordinate, entityKey: String? = nil, name: String? = nil, estimatedAddress: String? = nil, annotation: String? = nil, temp: Bool = false) {
        self.init(
            coordinate: coordinate.clCoordinate,
            entityKey: entityKey,
            name: name,
            estimatedAddress: estimatedAddress,
            annotation: annotation,
            temp: temp
        )
    }
    
    convenience init(location: GenericLocation, name: String? = nil, estimatedAddress: String? = nil, annotation: String? = nil, temp: Bool = false) {
        self.init()
        
        // Set location info for re-caching
        latitude = location.latitude
        longitude = location.longitude
        
        // Set the nickname
        if let name = name, name.isEmpty == false {
            nickname = name
        } else {
            nickname = nil
        }
        
        // Set the estimated address from the generic location
        if let estimatedAddress = estimatedAddress, estimatedAddress.isEmpty == false {
            self.estimatedAddress = estimatedAddress
        } else {
            self.estimatedAddress = nil
        }
        
        if let annotation = annotation, annotation.isEmpty == false {
            self.annotation = annotation
        } else {
            self.annotation = nil
        }
        
        // Set temporary status
        isTemp = temp
    }
    
    convenience init?(markerParameters: MarkerParameters, entity: POI) {
        guard let id = markerParameters.id else { return nil }
        
        self.init()

        self.id = id
        if entity is GenericLocation {
            self.entityKey = nil
        } else {
            self.entityKey = entity.key
        }
        self.isNew = true
        self.isTemp = false
        
        self.latitude = markerParameters.location.coordinate.latitude
        self.longitude = markerParameters.location.coordinate.longitude
        
        if let nickname = markerParameters.nickname, nickname.isEmpty == false {
            self.nickname = nickname
        } else {
            self.nickname = nil
        }
        
        if let estimatedAddress = markerParameters.estimatedAddress, estimatedAddress.isEmpty == false {
            self.estimatedAddress = estimatedAddress
        } else {
            self.estimatedAddress = nil
        }
        
        if let annotation = markerParameters.annotation, annotation.isEmpty == false {
            self.annotation = annotation
        } else {
            self.annotation = nil
        }
    }
    
    // MARK: Methods
    
    /// Helper method for calculating the distance from this RealmReferenceEntity to
    /// another coordinate.
    ///
    /// - Parameter from: The other location
    /// - Returns: Distance to the other location
    func distanceToClosestLocation(from location: CLLocation) -> CLLocationDistance {
        if let poi = _poi {
            return poi.distanceToClosestLocation(from: location)
        }
        
        return SSGeoMath.distanceMeters(from: geoCoordinate, to: location.coordinate.ssGeoCoordinate)
    }
    
    /// Bearing from the entity to the user's location
    ///
    /// - Parameter to: The user's location
    /// - Returns: Bearing from the entity to the user's location
    func bearingToClosestLocation(from location: CLLocation) -> CLLocationDirection {
        if let poi = _poi {
            return poi.bearingToClosestLocation(from: location)
        }
        
        return SSGeoMath.initialBearingDegrees(from: location.coordinate.ssGeoCoordinate, to: geoCoordinate)
    }
    
    /// Helper method for calculating the closest location on the underlying POI for this
    /// RealmReferenceEntity. Uses entrances on the entity if any exist.
    ///
    /// - Parameter location: The user's location
    /// - Returns: Closest location on the RealmReferenceEntity
    func closestLocation(from location: CLLocation) -> CLLocation {
        if let poi = _poi {
            return poi.closestLocation(from: location, useEntranceIfAvailable: true)
        }
        
        return geoCoordinate.clLocation
    }
    
    /// Gets the POI for the reference entity.
    ///
    /// - Returns: A POI referenced by this RealmReferenceEntity
    func getPOI() -> POI {
        return _poi ?? GenericLocation(ref: domainEntity)
    }
    
    /// Updates the lastSelectedDate of the reference entity and, if the reference entity is not a
    /// generic location, the lastSelectedDate of the underlying POI type in the cache.
    ///
    /// - Parameter date: Date to set
    /// - Throws: If the realms cannot be accessed or the update cannot be committed
    func updateLastSelectedDate(to date: Date = Date()) throws {
        let database = try RealmHelper.getDatabaseRealm()
        
        try database.write {
            self.lastSelectedDate = date
        }
        
        if let entity = getPOI() as? Object {
            let cache = try RealmHelper.getCacheRealm()
            
            try cache.write {
                entity[POI.Keys.lastSelectedDate] = date
            }
        }
        
        ReferenceEntityRuntime.notifyReferenceEntityUpdated(id: id)
    }
    
    func setTemporary(_ flag: Bool) throws {
        let database = try RealmHelper.getDatabaseRealm()
        
        let newFlag = self.isTemp && !flag
        try database.write {
            self.isTemp = flag
            self.isNew = newFlag
        }
        
        ReferenceEntityRuntime.notifyReferenceEntityUpdated(id: id)
    }
    
    // MARK: Static Methods

    static func entity(byID id: String) -> RealmReferenceEntity? {
        guard let database = try? RealmHelper.getDatabaseRealm() else {
            return nil
        }

        return database.object(ofType: RealmReferenceEntity.self, forPrimaryKey: id)
    }

    static func markSelected(id: String) throws {
        guard let entity = entity(byID: id) else {
            return
        }

        try entity.updateLastSelectedDate()
    }

    static func importFromCloud(markerParameters: MarkerParameters,
                                entity: POI,
                                using spatialRead: ReferenceReadContract) async throws {
        guard let referenceEntity = RealmReferenceEntity(markerParameters: markerParameters, entity: entity) else {
            throw ReferenceEntityError.cannotAddMarker
        }

        let markerID = referenceEntity.id

        try autoreleasepool {
            let database = try RealmHelper.getDatabaseRealm()

            try database.write {
                database.add(referenceEntity, update: .modified)
            }
        }

        try await Route.updateWaypointInAllRoutes(markerId: markerID, using: spatialRead)
    }
    
    /// Constructs and saves a reference point with the POI referred to by the supplied
    /// entity key. A nickname can optionally be set for the new reference entity. If the
    /// entityKey parameter corresponds to an Address entity, the estimatedAddress property
    /// will be ignored in favor of the actual address.
    ///
    /// - Parameters:
    ///   - entityKey: key of the underlying POI this reference entity refers to
    ///   - nickname: nickname of the reference entity
    ///   - estimatedAddress: estimated address of the reference entity
    ///   - temporary: flag indicating if the new reference entity is temporary (an audio beacon) or not
    /// - Returns: ID of the new reference point
    /// - Throws: If the database/cache cannot be accessed or the new reference entity cannot be added
    static func addTemporary(entityKey: String,
                             estimatedAddress: String?) throws -> String {
        try addSynchronously(entityKey: entityKey,
                             nickname: nil,
                             estimatedAddress: estimatedAddress,
                             annotation: nil,
                             temporary: true,
                             context: nil,
                             notify: true)
    }

    static func addTemporary(location: GenericLocation,
                             estimatedAddress: String?) throws -> String {
        try addSynchronously(location: location,
                             nickname: nil,
                             estimatedAddress: estimatedAddress,
                             annotation: nil,
                             temporary: true,
                             context: nil,
                             notify: true)
    }

    static func addTemporary(location: GenericLocation,
                             nickname: String?,
                             estimatedAddress: String?) throws -> String {
        try addSynchronously(location: location,
                             nickname: nickname,
                             estimatedAddress: estimatedAddress,
                             annotation: nil,
                             temporary: true,
                             context: nil,
                             notify: true)
    }

    private static func addSynchronously(entityKey: String,
                                         nickname: String? = nil,
                                         estimatedAddress: String? = nil,
                                         annotation: String? = nil,
                                         temporary: Bool = false,
                                         context: String? = nil,
                                         notify: Bool = true) throws -> String {
        if let existingMarker = SpatialDataCache.referenceEntityByEntityKey(entityKey) {
            // Update and return the existing marker
            try update(entity: existingMarker,
                       nickname: nickname,
                       address: estimatedAddress,
                       annotation: annotation,
                       context: context,
                       isTemp: temporary)

            return existingMarker.id
        }

        return try addNewReferenceEntityForEntityKey(entityKey,
                                                     nickname: nickname,
                                                     estimatedAddress: estimatedAddress,
                                                     annotation: annotation,
                                                     temporary: temporary,
                                                     context: context,
                                                     notify: notify)
    }

    static func add(entityKey: String,
                    nickname: String? = nil,
                    estimatedAddress: String? = nil,
                    annotation: String? = nil,
                    temporary: Bool = false,
                    context: String? = nil,
                    notify: Bool = true,
                    using spatialRead: ReferenceReadContract) async throws -> String {
        if let existingMarker = await spatialRead.referenceEntity(byEntityKey: entityKey) {
            try await update(id: existingMarker.id,
                             nickname: nickname,
                             address: estimatedAddress,
                             annotation: annotation,
                             context: context,
                             isTemp: temporary,
                             using: spatialRead)
            return existingMarker.id
        }

        guard let entity = await spatialRead.poi(byKey: entityKey) else {
            throw ReferenceEntityError.entityDoesNotExist
        }

        let markerID = try addNewReferenceEntity(for: entity,
                                                 entityKey: entityKey,
                                                 nickname: nickname,
                                                 estimatedAddress: estimatedAddress,
                                                 annotation: annotation,
                                                 temporary: temporary,
                                                 context: context,
                                                 notify: notify,
                                                 updateCloudSynchronously: false)

        if !temporary,
           let markerParameters = try markerParametersForCloudStore(markerID: markerID,
                                                                    entity: entity) {
            ReferenceEntityRuntime.updateReferenceInCloud(markerParameters)
        }

        return markerID
    }
    
    /// Updates the given reference entity
    ///
    /// - Parameters:
    ///   - entity: The reference entity to update
    ///   - nickname: Nickname for the reference entity (required since this reference doesn't refer to an underlying POI object)
    ///   - estimatedAddress: estimated address of the reference entity
    ///   - annotation: annotation of the reference entity
    ///   - isTemp: `true` if the reference entity is temporary (e.g. audio beacon), otherwise `false`
    /// - Throws: If the database/cache cannot be accessed or the new reference entity cannot be added
    static func update(entity: RealmReferenceEntity,
                       location: CLLocationCoordinate2D? = nil,
                       nickname: String?,
                       address: String?,
                       annotation: String?,
                       context: String? = nil,
                       isTemp: Bool,
                       updateRoutesSynchronously: Bool = true,
                       preservePOINameOnLocationChange: Bool = true,
                       updateDate: Date = Date(),
                       updatePOILastSelectedViaStore: Bool = true,
                       updateCloudSynchronously: Bool = true) throws {
        var locChanged: Bool = false
        if let loc = location, loc != entity.coordinate {
            locChanged = true
        }
        
        if entity.nickname == nickname, entity.estimatedAddress == address, entity.annotation == annotation, entity.isTemp == isTemp, !locChanged {
            // There is nothing to update
            return
        }
        
        let now = updateDate
        
        var updatedNickname = nickname
        if locChanged, nickname == nil, preservePOINameOnLocationChange {
            // Because the location has changed, we are going to disconnect this marker from its
            // underlying POI and use a generic location instead. In the edge case where no nickname
            // has been specified, make sure we at least keep the underlying POI's name.
            updatedNickname = entity.getPOI().localizedName
        }
        
        try autoreleasepool {
            let database = try RealmHelper.getDatabaseRealm()
            
            let previousIsTemp = entity.isTemp
            
            try database.write {
                // If the location was changed, then remove ref to the underlying POI (if one exists), and store
                // the new location
                if locChanged, let loc = location {
                    entity.entityKey = nil
                    entity.latitude = loc.latitude
                    entity.longitude = loc.longitude
                }
                
                // Ensure the nickname is not empty and is not the same as the given name
                entity.nickname = updatedNickname
                
                // If an address was provided, update it
                if let addressLine = address, addressLine.isEmpty == false {
                    entity.estimatedAddress = addressLine
                }
                
                if let annotation = annotation, annotation.isEmpty == false {
                    entity.annotation = annotation
                } else {
                    entity.annotation = nil
                }
                
                entity.isTemp = isTemp
                // If the marker is temporary, do not set the `isNew` flag
                // If the marker was previously temporary, set the `isNew` flag
                entity.isNew = isTemp ? false : previousIsTemp
                
                entity.lastUpdatedDate = now
            }
            
            if updatePOILastSelectedViaStore {
                // Update the lastSelectedDate to support recents
                try entity.updateLastSelectedDate(to: now)
            } else {
                try database.write {
                    entity.lastSelectedDate = now
                }
            }
            
            if updateCloudSynchronously,
               let markerParameters = markerParametersForCloudStore(marker: entity,
                                                                   entity: entity.getPOI()) {
                ReferenceEntityRuntime.updateReferenceInCloud(markerParameters)
            }
            
            ReferenceEntityRuntime.didUpdateReferenceEntity(id: entity.id,
                                                            includesAnnotation: entity.annotation?.isEmpty == false,
                                                            context: context)
            
            if locChanged, updateRoutesSynchronously {
                // Update all routes whose first waypoint is the given entity
                try Route.updateWaypointInAllRoutes(markerId: entity.id)
            }
        }
    }

    static func update(entity: RealmReferenceEntity,
                       location: CLLocationCoordinate2D? = nil,
                       nickname: String?,
                       address: String?,
                       annotation: String?,
                       context: String? = nil,
                       isTemp: Bool,
                       using spatialRead: ReferenceReadContract) async throws {
        var locChanged: Bool = false
        if let loc = location, loc != entity.coordinate {
            locChanged = true
        }

        if entity.nickname == nickname,
           entity.estimatedAddress == address,
           entity.annotation == annotation,
           entity.isTemp == isTemp,
           !locChanged {
            return
        }

        let originalEntityKey = entity.entityKey
        let updateDate = Date()

        var resolvedNickname = nickname
        var resolvedPOI: POI?
        if locChanged,
           nickname == nil,
           let entityKey = entity.entityKey {
            resolvedPOI = await spatialRead.poi(byKey: entityKey)
            resolvedNickname = resolvedPOI?.localizedName
        }

        try update(entity: entity,
                   location: location,
                   nickname: resolvedNickname,
                   address: address,
                   annotation: annotation,
                   context: context,
                   isTemp: isTemp,
                   updateRoutesSynchronously: false,
                   preservePOINameOnLocationChange: false,
                   updateDate: updateDate,
                   updatePOILastSelectedViaStore: false,
                   updateCloudSynchronously: false)

        if !locChanged,
           let entityKey = originalEntityKey {
            resolvedPOI = try await updatePOILastSelectedDate(forEntityKey: entityKey,
                                                              to: updateDate,
                                                              using: spatialRead)
        }

        if !isTemp,
           let markerParameters = await markerParametersForCloudUpdate(entity: entity,
                                                                       resolvedPOI: resolvedPOI,
                                                                       using: spatialRead) {
            ReferenceEntityRuntime.updateReferenceInCloud(markerParameters)
        }

        if locChanged {
            try await Route.updateWaypointInAllRoutes(markerId: entity.id, using: spatialRead)
        }
    }

    private static func updatePOILastSelectedDate(forEntityKey entityKey: String,
                                                  to date: Date,
                                                  using spatialRead: ReferenceReadContract) async throws -> POI? {
        guard let poi = await spatialRead.poi(byKey: entityKey) else {
            return nil
        }

        if let persistedPOI = poi as? Object {
            let cache = try RealmHelper.getCacheRealm()

            try cache.write {
                persistedPOI[POI.Keys.lastSelectedDate] = date
            }
        }

        return poi
    }

    private static func markerParametersForCloudUpdate(entity: RealmReferenceEntity,
                                                       resolvedPOI: POI?,
                                                       using spatialRead: ReferenceReadContract) async -> MarkerParameters? {
        let cloudPOI: POI?
        if let resolvedPOI {
            cloudPOI = resolvedPOI
        } else {
            cloudPOI = await resolvedCloudPOI(for: entity, using: spatialRead)
        }

        if let poi = cloudPOI {
            return MarkerParameters(entity: poi,
                                    markerId: entity.id,
                                    estimatedAddress: entity.estimatedAddress,
                                    nickname: entity.nickname,
                                    annotation: entity.annotation,
                                    lastUpdatedDate: entity.lastUpdatedDate)
        }

        let fallbackName = entity.nickname ?? entity.estimatedAddress ?? ""
        let fallbackPOI = GenericLocation(coordinate: entity.geoCoordinate,
                                          name: fallbackName,
                                          address: entity.estimatedAddress)
        return MarkerParameters(entity: fallbackPOI,
                                markerId: entity.id,
                                estimatedAddress: entity.estimatedAddress,
                                nickname: entity.nickname,
                                annotation: entity.annotation,
                                lastUpdatedDate: entity.lastUpdatedDate)
    }

    private static func resolvedCloudPOI(for entity: RealmReferenceEntity,
                                         using spatialRead: ReferenceReadContract) async -> POI? {
        guard let entityKey = entity.entityKey else {
            return nil
        }

        return await spatialRead.poi(byKey: entityKey)
    }

    static func update(id: String,
                       location: CLLocationCoordinate2D? = nil,
                       nickname: String?,
                       address: String?,
                       annotation: String?,
                       context: String? = nil,
                       isTemp: Bool,
                       using spatialRead: ReferenceReadContract) async throws {
        let database = try RealmHelper.getDatabaseRealm()

        guard let entity = database.object(ofType: RealmReferenceEntity.self, forPrimaryKey: id) else {
            return
        }

        try await update(entity: entity,
                         location: location,
                         nickname: nickname,
                         address: address,
                         annotation: annotation,
                         context: context,
                         isTemp: isTemp,
                         using: spatialRead)
    }
    
    /// Constructs and saves a reference point for the generic location described by the
    /// provided coordinate and nickname.
    ///
    /// - Parameters:
    ///   - coordinate: Location of the reference entity
    ///   - nickname: Nickname for the reference entity (required since this reference doesn't refer to an underlying POI object)
    ///   - estimatedAddress: estimated address of the reference entity
    ///   - temporary: flag indicating if the new reference entity is temporary (an audio beacon) or not
    /// - Returns: ID of the new reference point
    /// - Throws: If the database/cache cannot be accessed or the new reference entity cannot be added
    private static func addSynchronously(location: GenericLocation,
                                         nickname: String? = nil,
                                         estimatedAddress: String? = nil,
                                         annotation: String? = nil,
                                         temporary: Bool = false,
                                         context: String? = nil,
                                         notify: Bool = true) throws -> String {
        // If an existing marker is found at the same location, then return that marker's id. In the case that
        // `existingFlag.isTemp` matches `temporary`, then we can also update the underlying marker in case any
        // of it's info has changed. If `existingFlag.isTemp` is false, `temporary` is true, and all other properties
        // match, then we can also update the marker to set `isTemp` to false. This covers the only edge case where
        // we allow permanent markers to become temporary: when a marker is deleted and there is currently a beacon
        // set on the location of that marker.
        if let existingMarker = SpatialDataCache.referenceEntityByGenericLocation(location) {
            let tempStatusMatches = existingMarker.isTemp == temporary
            let propertiesMatch = existingMarker.nickname == nickname &&
                                  existingMarker.estimatedAddress == estimatedAddress &&
                                  existingMarker.annotation == annotation
            let shouldDowngradeMarker = !existingMarker.isTemp && temporary && propertiesMatch

            if tempStatusMatches || shouldDowngradeMarker {
                try update(entity: existingMarker,
                           nickname: nickname,
                           address: estimatedAddress,
                           annotation: annotation,
                           context: context,
                           isTemp: temporary)
            }

            return existingMarker.id
        }

        return try addNewReferenceEntityForLocation(location,
                                                    nickname: nickname,
                                                    estimatedAddress: estimatedAddress,
                                                    annotation: annotation,
                                                    temporary: temporary,
                                                    context: context,
                                                    notify: notify)
    }

    static func add(location: GenericLocation,
                    nickname: String? = nil,
                    estimatedAddress: String? = nil,
                    annotation: String? = nil,
                    temporary: Bool = false,
                    context: String? = nil,
                    notify: Bool = true,
                    using spatialRead: ReferenceReadContract) async throws -> String {
        if let existingMarker = await spatialRead.referenceEntity(byGenericLocation: location) {
            let tempStatusMatches = existingMarker.isTemp == temporary
            let propertiesMatch = existingMarker.nickname == nickname &&
                                  existingMarker.estimatedAddress == estimatedAddress &&
                                  existingMarker.annotation == annotation
            let shouldDowngradeMarker = !existingMarker.isTemp && temporary && propertiesMatch

            if tempStatusMatches || shouldDowngradeMarker {
                try await update(id: existingMarker.id,
                                 nickname: nickname,
                                 address: estimatedAddress,
                                 annotation: annotation,
                                 context: context,
                                 isTemp: temporary,
                                 using: spatialRead)
            }

            return existingMarker.id
        }

        return try addNewReferenceEntityForLocation(location,
                                                    nickname: nickname,
                                                    estimatedAddress: estimatedAddress,
                                                    annotation: annotation,
                                                    temporary: temporary,
                                                    context: context,
                                                    notify: notify)
    }

    private static func addNewReferenceEntityForEntityKey(_ entityKey: String,
                                                           nickname: String?,
                                                           estimatedAddress: String?,
                                                           annotation: String?,
                                                           temporary: Bool,
                                                           context: String?,
                                                           notify: Bool) throws -> String {
        try autoreleasepool {
            guard let entity = SpatialDataCache.searchByKey(key: entityKey) else {
                // Return if entity does not exist (or doesn't exist in Realm)
                throw ReferenceEntityError.entityDoesNotExist
            }

            return try addNewReferenceEntity(for: entity,
                                             entityKey: entityKey,
                                             nickname: nickname,
                                             estimatedAddress: estimatedAddress,
                                             annotation: annotation,
                                             temporary: temporary,
                                             context: context,
                                             notify: notify)
        }
    }

    private static func addNewReferenceEntity(for entity: POI,
                                              entityKey: String,
                                              nickname: String?,
                                              estimatedAddress: String?,
                                              annotation: String?,
                                              temporary: Bool,
                                              context: String?,
                                              notify: Bool,
                                              updateCloudSynchronously: Bool = true) throws -> String {
        let database = try RealmHelper.getDatabaseRealm()
        let cache = try RealmHelper.getCacheRealm()

        // In the case that the new entity is an address, backup the address in the estimated address
        // field of the Reference Entity.
        var address = estimatedAddress
        if let addrEntity = entity as? Address {
            address = addrEntity.addressLine
        }

        let reference = RealmReferenceEntity(coordinate: entity.centroidCoordinate,
                                             entityKey: entityKey,
                                             name: nickname,
                                             estimatedAddress: address,
                                             annotation: annotation,
                                             temp: temporary)
        reference.lastUpdatedDate = Date()

        // Set the last selected date on the POI.
        if let rlmEntity = entity as? Object {
            try cache.write {
                rlmEntity[POI.Keys.lastSelectedDate] = reference.lastSelectedDate
            }
        }

        try database.write {
            database.add(reference, update: .modified)
        }

        if !temporary {
            if updateCloudSynchronously {
                if let markerParameters = markerParametersForCloudStore(marker: reference,
                                                                        entity: entity) {
                    ReferenceEntityRuntime.updateReferenceInCloud(markerParameters)
                }
            }

            let telemetryType: ReferenceEntityRuntime.AddedTelemetryType = entity is Address ? .address : .poi
            ReferenceEntityRuntime.didAddReferenceEntity(id: reference.id,
                                                         type: telemetryType,
                                                         includesAnnotation: reference.annotation?.isEmpty == false,
                                                         context: context,
                                                         notify: notify)
        } else if notify {
            ReferenceEntityRuntime.didAddReferenceEntity(id: reference.id,
                                                         type: nil,
                                                         includesAnnotation: reference.annotation?.isEmpty == false,
                                                         context: context,
                                                         notify: true)
        }

        return reference.id
    }

    private static func markerParametersForCloudStore(markerID: String,
                                                      entity: POI) throws -> MarkerParameters? {
        let database = try RealmHelper.getDatabaseRealm()
        guard let persistedMarker = database.object(ofType: RealmReferenceEntity.self,
                                                    forPrimaryKey: markerID) else {
            return nil
        }

        return markerParametersForCloudStore(marker: persistedMarker,
                                             entity: entity)
    }

    private static func markerParametersForCloudStore(marker: RealmReferenceEntity,
                                                      entity: POI) -> MarkerParameters? {
        MarkerParameters(entity: entity,
                         markerId: marker.id,
                         estimatedAddress: marker.estimatedAddress,
                         nickname: marker.nickname,
                         annotation: marker.annotation,
                         lastUpdatedDate: marker.lastUpdatedDate)
    }

    private static func addNewReferenceEntityForLocation(_ location: GenericLocation,
                                                         nickname: String?,
                                                         estimatedAddress: String?,
                                                         annotation: String?,
                                                         temporary: Bool,
                                                         context: String?,
                                                         notify: Bool) throws -> String {
        try autoreleasepool {
            let database = try RealmHelper.getDatabaseRealm()

            let name: String?
            if let nickname, nickname.isEmpty == false {
                name = nickname
            } else {
                name = location.name
            }

            let address: String?
            // If an address was provided by the generic location, use it
            if let addressLine = location.addressLine, addressLine.isEmpty == false {
                address = addressLine
            } else {
                address = estimatedAddress
            }

            let reference = RealmReferenceEntity(location: location,
                                                 name: name,
                                                 estimatedAddress: address,
                                                 annotation: annotation,
                                                 temp: temporary)
            reference.lastUpdatedDate = Date()

            try database.write {
                database.add(reference, update: .modified)
            }

            if !temporary {
                if let markerParameters = markerParametersForCloudStore(marker: reference,
                                                                        entity: location) {
                    ReferenceEntityRuntime.updateReferenceInCloud(markerParameters)
                }

                ReferenceEntityRuntime.didAddReferenceEntity(id: reference.id,
                                                             type: .genericLocation,
                                                             includesAnnotation: reference.annotation?.isEmpty == false,
                                                             context: context,
                                                             notify: notify)
            } else if notify {
                ReferenceEntityRuntime.didAddReferenceEntity(id: reference.id,
                                                             type: nil,
                                                             includesAnnotation: reference.annotation?.isEmpty == false,
                                                             context: context,
                                                             notify: true)
            }

            return reference.id
        }
    }
    
    /// Removes the reference entity with the corresponding ID. If the reference entity is currently set as the
    /// destination, it is set as a temporary entity instead of completely removing it.
    ///
    /// - Parameter id: ID of the reference entity to remove
    /// - Throws: If the database/cache cannot be accessed or no reference entity exists for the provided ID
    static func remove(id: String, using spatialRead: ReferenceReadContract) async throws {
        if try ReferenceEntityRuntime.setDestinationTemporaryIfMatchingID(id) {
            ReferenceEntityRuntime.notifyReferenceEntityRemoved(id: id)
            return
        }

        let database = try RealmHelper.getDatabaseRealm()

        guard let entity = database.object(ofType: RealmReferenceEntity.self, forPrimaryKey: id) else {
            return
        }

        if entity.entityKey == nil {
            ReferenceEntityRuntime.removeCalloutHistoryForMarkerID(entity.id)
        }

        try await Route.removeWaypointFromAllRoutes(markerId: id, using: spatialRead)

        ReferenceEntityRuntime.removeReferenceFromCloud(markerID: entity.id)

        try database.write {
            database.delete(entity)
        }

        ReferenceEntityRuntime.didRemoveReferenceEntity(id: id)
    }

    static func removeAllTemporary() throws {
        let database = try RealmHelper.getDatabaseRealm()
        let temporaryEntities = database.objects(RealmReferenceEntity.self).filter("isTemp == true")

        guard !temporaryEntities.isEmpty else {
            return
        }

        try database.write {
            database.delete(temporaryEntities)
        }
    }

    static func setTemporary(id: String, temporary: Bool) throws {
        let database = try RealmHelper.getDatabaseRealm()

        guard let entity = database.object(ofType: RealmReferenceEntity.self, forPrimaryKey: id) else {
            return
        }

        try entity.setTemporary(temporary)
    }

    static func clearNew() throws {
        let database = try RealmHelper.getDatabaseRealm()
        let newEntities = database.objects(RealmReferenceEntity.self).filter("isNew == true")

        guard !newEntities.isEmpty else {
            return
        }

        try database.write {
            for entity in newEntities {
                entity.isNew = false
            }
        }
    }

    static func cleanCorruptEntities(using spatialRead: ReferenceReadContract) async throws {
        let entities = try RealmHelper.getDatabaseRealm().objects(RealmReferenceEntity.self).filter("isTemp == false")
        let candidates = entities.map { entity in
            (id: entity.id, entityKey: entity.entityKey, nickname: entity.nickname)
        }
        var corruptIDs: [String] = []

        for candidate in candidates {
            guard candidate.nickname == nil else {
                continue
            }

            if let entityKey = candidate.entityKey,
               await spatialRead.poi(byKey: entityKey) != nil {
                continue
            }

            corruptIDs.append(candidate.id)
        }

        for id in corruptIDs {
            try await RealmReferenceEntity.remove(id: id, using: spatialRead)
        }
    }
}

extension RealmReferenceEntity {
    @MainActor
    var domainEntity: ReferenceEntity {
        ReferenceEntity(realmEntity: self)
    }
}
