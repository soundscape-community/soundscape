//
//  ReferenceEntity.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import SSData

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

final class ReferenceEntity: Identifiable {
    // MARK: Constants
    
    struct Keys {
        static let entityId = "GDAReferenceEntityID"
    }
    
    // MARK: Properties

    var id: String = UUID().uuidString // Primary key
    var entityKey: String?
    var lastUpdatedDate: Date?
    var lastSelectedDate: Date? = Date()
    var isNew: Bool = true
    var isTemp: Bool = true
    
    var latitude: CLLocationDegrees = 0.0
    var longitude: CLLocationDegrees = 0.0
    
    var nickname: String?
    var estimatedAddress: String?
    var annotation: String?
    
    private var savedPlace: SavedPlace?
    
    private var _poi: POI? {
        guard let key = entityKey else { return nil }
        return SpatialDataCache.searchMapByKey(key) ?? restoredPOI
    }

    var restoredPOI: POI? {
        guard let place = savedPlace, let key = entityKey else { return nil }
        if place.isAddress {
            let address = Address()
            address.key = key
            address.name = place.name
            address.addressLine = place.address
            address.streetName = place.street
            address.latitude = latitude
            address.longitude = longitude
            address.centroidLatitude = latitude
            address.centroidLongitude = longitude
            return address
        }
        return GDASpatialDataResultEntity(data: MapFeature(key: key, name: place.name, addressLine: place.address,
                                                           streetName: place.street, latitude: latitude, longitude: longitude))
    }

    convenience init(stored: Marker) {
        self.init()
        id = stored.id
        entityKey = stored.entityKey
        latitude = stored.latitude
        longitude = stored.longitude
        nickname = stored.nickname
        estimatedAddress = stored.estimatedAddress
        annotation = stored.annotation
        lastUpdatedDate = stored.lastUpdatedDate
        lastSelectedDate = stored.lastSelectedDate
        isNew = stored.isNew
        isTemp = stored.isTemp
        savedPlace = stored.place
    }

    var stored: Marker {
        Marker(id: id, entityKey: entityKey, latitude: latitude, longitude: longitude, nickname: nickname,
               estimatedAddress: estimatedAddress, annotation: annotation, lastUpdatedDate: lastUpdatedDate,
               lastSelectedDate: lastSelectedDate, isNew: isNew, isTemp: isTemp, place: savedPlace)
    }

    // MARK: Computed Properties
    
    /// CLLocationCoordinate2D for the referenced entity
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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
    
    // MARK: Methods
    
    /// Helper method for calculating the distance from this ReferenceEntity to
    /// another coordinate.
    ///
    /// - Parameter from: The other location
    /// - Returns: Distance to the other location
    func distanceToClosestLocation(from location: CLLocation) -> CLLocationDistance {
        if let poi = _poi {
            return poi.distanceToClosestLocation(from: location)
        }
        
        return self.coordinate.distance(from: location.coordinate)
    }
    
    /// Bearing from the entity to the user's location
    ///
    /// - Parameter to: The user's location
    /// - Returns: Bearing from the entity to the user's location
    func bearingToClosestLocation(from location: CLLocation) -> CLLocationDirection {
        if let poi = _poi {
            return poi.bearingToClosestLocation(from: location)
        }
        
        return location.coordinate.bearing(to: coordinate)
    }
    
    /// Helper method for calculating the closest location on the underlying POI for this
    /// ReferenceEntity. Uses entrances on the entity if any exist.
    ///
    /// - Parameter location: The user's location
    /// - Returns: Closest location on the ReferenceEntity
    func closestLocation(from location: CLLocation) -> CLLocation {
        if let poi = _poi {
            return poi.closestLocation(from: location, useEntranceIfAvailable: true)
        }
        
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    /// Gets the POI for the reference entity.
    ///
    /// - Returns: A POI referenced by this ReferenceEntity
    func getPOI() -> POI {
        return _poi ?? GenericLocation(ref: self)
    }
    
    func updateLastSelectedDate(to date: Date = Date()) throws {
        try StorageContext.shared.selectMarker(id, at: date)
        lastSelectedDate = date
        SpatialDataCache.recordSelection(getPOI(), at: date)
        Self.notifyEntityUpdated(id)
    }

    func setTemporary(_ flag: Bool) throws {
        try StorageContext.shared.setMarkerTemporary(id, flag)
        isNew = isTemp && !flag
        isTemp = flag
        Self.notifyEntityUpdated(id)
    }

    // MARK: Static Methods
    
    static func add(detail: LocationDetail, telemetryContext: String?, isTemporary: Bool = false, notify: Bool = true) throws -> String {
        if let id = detail.markerId, let marker = SpatialDataCache.referenceEntityByKey(id) {
            try update(entity: marker, location: detail.location.coordinate, nickname: detail.nickname, address: detail.estimatedAddress, annotation: detail.annotation, context: telemetryContext, isTemp: isTemporary)
            
            return id
        }
        
        switch detail.source {
        case .coordinate(let at):
            let location = GenericLocation(lat: at.coordinate.latitude, lon: at.coordinate.longitude,
                                           name: detail.resolvedPOI?.localizedName ?? "", address: detail.resolvedPOI?.addressLine)
            return try add(location: location, nickname: detail.nickname, estimatedAddress: detail.estimatedAddress, annotation: detail.annotation, temporary: isTemporary, context: telemetryContext, notify: notify)
        case .entity:
            guard let poi = detail.resolvedPOI else { throw ReferenceEntityError.entityDoesNotExist }
            return try add(poi: poi, nickname: detail.nickname, address: detail.estimatedAddress,
                           annotation: detail.annotation, context: telemetryContext, temporary: isTemporary, notify: notify)
        case .designData:
            throw ReferenceEntityError.cannotAddMarker
        case .screenshots:
            throw ReferenceEntityError.cannotAddMarker
        }
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
    static func add(entityKey: String, nickname: String? = nil, estimatedAddress: String? = nil, annotation: String? = nil, temporary: Bool = false, context: String? = nil, notify: Bool = true) throws -> String {
        if let existing = SpatialDataCache.referenceEntityByEntityKey(entityKey) {
            try update(entity: existing, nickname: nickname, address: estimatedAddress,
                       annotation: annotation, context: context, isTemp: temporary)
            return existing.id
        }
        guard let entity = SpatialDataCache.searchByKey(key: entityKey) else {
            throw ReferenceEntityError.entityDoesNotExist
        }
        let reference = makeReference(for: entity, nickname: nickname, address: estimatedAddress,
                                      annotation: annotation, temporary: temporary)
        try persistNew(reference, notify: notify)
        return reference.id
    }

    static func add(poi: POI, nickname: String?, address: String?, annotation: String?,
                    context: String?, temporary: Bool = false, notify: Bool = true) throws -> String {
        if let existing = SpatialDataCache.referenceEntityByEntityKey(poi.key) {
            try update(entity: existing, nickname: nickname, address: address, annotation: annotation,
                       context: context, isTemp: temporary)
            return existing.id
        }
        let reference = makeReference(for: poi, nickname: nickname, address: address, annotation: annotation,
                                      temporary: temporary, preservePlace: SpatialDataCache.searchMapByKey(poi.key) == nil)
        try persistNew(reference, notify: notify)
        return reference.id
    }

    static func makeReference(for entity: POI, nickname: String?, address: String?,
                              annotation: String?, temporary: Bool = false, preservePlace: Bool = false) -> ReferenceEntity {
        let reference = ReferenceEntity(coordinate: entity.centroidCoordinate, entityKey: entity.key,
                                        name: nickname, estimatedAddress: entity is Address ? entity.addressLine : address,
                                        annotation: annotation, temp: temporary)
        if entity is Address || preservePlace {
            reference.savedPlace = SavedPlace(name: entity.localizedName, address: entity.addressLine,
                                              street: entity.streetName, isAddress: entity is Address)
        }
        reference.lastUpdatedDate = Date()
        return reference
    }

    private static func persistNew(_ reference: ReferenceEntity, notify: Bool) throws {
        try StorageContext.shared.saveMarker(reference.stored)
        SpatialDataCache.recordSelection(reference.getPOI())
        if !reference.isTemp {
            NSUserActivity(userAction: .saveMarker).becomeCurrent()
        }
        if notify { notifyEntityAdded(reference.id) }
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
    static func update(entity: ReferenceEntity, location: CLLocationCoordinate2D? = nil, nickname: String?, address: String?, annotation: String?, context: String? = nil, isTemp: Bool) throws {
        var locChanged: Bool = false
        if let loc = location, loc != entity.coordinate {
            locChanged = true
        }
        
        if entity.nickname == nickname, entity.estimatedAddress == address, entity.annotation == annotation, entity.isTemp == isTemp, !locChanged {
            // There is nothing to update
            return
        }
        
        let now = Date()
        
        var updatedNickname = nickname
        if locChanged, nickname == nil {
            // Because the location has changed, we are going to disconnect this marker from its
            // underlying POI and use a generic location instead. In the edge case where no nickname
            // has been specified, make sure we at least keep the underlying POI's name.
            updatedNickname = entity.getPOI().localizedName
        }
        
        let edited = ReferenceEntity(stored: entity.stored)
        if locChanged, let loc = location {
            edited.entityKey = nil
            edited.savedPlace = nil
            edited.latitude = loc.latitude
            edited.longitude = loc.longitude
        }
        edited.nickname = updatedNickname
        if let address, !address.isEmpty { edited.estimatedAddress = address }
        edited.annotation = annotation?.isEmpty == false ? annotation : nil
        edited.isTemp = isTemp
        edited.isNew = !isTemp && entity.isTemp
        edited.lastUpdatedDate = now
        edited.lastSelectedDate = now
        try StorageContext.shared.saveMarker(edited.stored)
        SpatialDataCache.recordSelection(edited.getPOI())
        notifyEntityUpdated(edited.id)
        if locChanged {
            for route in SpatialDataCache.routesContaining(markerId: edited.id)
                where route.waypoints.first?.markerId == edited.id {
                Route.notifyUpdated(route.id)
            }
        }
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
    static func add(location: GenericLocation, nickname: String? = nil, estimatedAddress: String? = nil, annotation: String? = nil, temporary: Bool = false, context: String? = nil, notify: Bool = true) throws -> String {
        return try autoreleasepool {
            
            // If an existing marker is found at the same location, then return that marker's id. In the case that
            // `existingFlag.isTemp` matches `temporary`, then we can also update the underlying marker in case any
            // of it's info has changed. If `existingFlag.isTemp` is false, `temporary` is true, and all other properties
            // match, then we can also update the marker to set `isTemp` to false. This covers the only edge case where
            // we allow permanent markers to become temporary: when a marker is deleted and there is currently a beacon
            // set on the location of that marker.
            if let existingMarker = SpatialDataCache.referenceEntityByGenericLocation(location, isTemp: nil) {
                let tempStatusMatches = existingMarker.isTemp == temporary
                let propertiesMatch = existingMarker.nickname == nickname &&
                                      existingMarker.estimatedAddress == estimatedAddress &&
                                      existingMarker.annotation == annotation
                let shouldDowngradeMarker = !existingMarker.isTemp && temporary && propertiesMatch
                
                if tempStatusMatches || shouldDowngradeMarker {
                    try update(entity: existingMarker, nickname: nickname, address: estimatedAddress, annotation: annotation, context: context, isTemp: temporary)
                }
                
                return existingMarker.id
            }
            
            var name: String?
            
            if let nickname = nickname, nickname.isEmpty == false {
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
            
            let reference = ReferenceEntity(location: location, name: name, estimatedAddress: address, annotation: annotation, temp: temporary)
            reference.lastUpdatedDate = Date()
            
            try persistNew(reference, notify: notify)
            return reference.id
        }
    }
    
    private static func notifyEntityAdded(_ id: String) {
        DispatchQueue.main.async {
            AppContext.process(MarkerAddedEvent(id))
            
            NotificationCenter.default.post(name: Notification.Name.markerAdded, object: self, userInfo: [ReferenceEntity.Keys.entityId: id])
        }
    }
    
    private static func notifyEntityUpdated(_ id: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .markerUpdated, object: self, userInfo: [Keys.entityId: id])
        }
    }
    
    private static func notifyEntityRemoved(_ id: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .markerRemoved, object: self, userInfo: [Keys.entityId: id])
        }
    }
    
    /// Removes the reference entity with the corresponding ID. If the reference entity is currently set as the
    /// destination, it is set as a temporary entity instead of completely removing it.
    ///
    /// - Parameter id: ID of the reference entity to remove
    /// - Throws: If the database/cache cannot be accessed or no reference entity exists for the provided ID
    static func remove(id: String) throws {
        if let destination = AppContext.shared.spatialDataContext.destinationManager.destination, destination.id == id {
            try destination.setTemporary(true)
            ReferenceEntity.notifyEntityRemoved(id)
            return
        }
        
        guard let entity = SpatialDataCache.referenceEntityByKey(id) else { return }
        let affected = try StorageContext.shared.deleteMarker(id)
        if entity.entityKey == nil {
            AppContext.shared.calloutHistory.remove { callout in
                (callout as? POICallout)?.key == id
            }
        }
        affected.forEach(Route.notifyUpdated)
        notifyEntityRemoved(id)
    }

    @MainActor
    static func eraseUserData() async throws {
        let (markerIDs, routeIDs) = try await StorageContext.shared.eraseUserData()
        if let guidance = AppContext.shared.eventProcessor.activeBehavior as? RouteGuidance,
           routeIDs.contains(guidance.content.id) {
            AppContext.shared.eventProcessor.deactivateCustom()
        }
        let removed = Set(markerIDs)
        let destinations = AppContext.shared.spatialDataContext.destinationManager
        if let key = destinations.destinationKey, removed.contains(key) {
            destinations.clearDestinationState(logContext: "settings.delete_user_data")
        }
        AppContext.shared.calloutHistory.remove { callout in
            (callout as? POICallout).map { removed.contains($0.key) } ?? false
        }
        routeIDs.forEach(Route.notifyDeleted)
        markerIDs.forEach(notifyEntityRemoved)
    }

    static func removeAllTemporary() throws {
        let storage = StorageContext.shared
        if storage.isUserStorageAvailable && !storage.markers.contains(where: \.isTemp) { return }
        let routes = try storage.deleteTemporaryMarkers()
        routes.forEach(Route.notifyUpdated)
    }

    static func deleteActionMake(id: String, deleted: (() -> Void)? = nil, canceled: (() -> Void)? = nil) -> UIAlertController {
        // Create the action buttons for the alert.
        let deleteAction = UIAlertAction(title: GDLocalizedString("general.alert.delete"), style: .destructive) { (_) in
            do {
                try ReferenceEntity.remove(id: id)
            } catch {
                GDLogAppError("Unable to successfully delete the reference entity (id: \(id))")
            }
            
            deleted?()
        }
        
        let cancelAction = UIAlertAction(title: GDLocalizedString("general.alert.cancel"), style: .cancel) { (_) in
            canceled?()
        }
        
        // Create and configure the alert controller.
        let alert = UIAlertController(title: GDLocalizedString("markers.destructive_delete_message"),
                                      message: GDLocalizedString("general.alert.destructive_undone_message"),
                                      preferredStyle: .alert)
        
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        
        return alert
    }
    
    static func objectKeys(sortedBy: SortStyle) -> [String] {
        let markers = SpatialDataCache.referenceEntities()
        switch sortedBy {
        case .alphanumeric:
            return markers.map { ($0.id, $0.name) }.sorted { $0.1 < $1.1 }.map { $0.0 }
        case .distance:
            let location = AppContext.shared.geolocationManager.location ?? CLLocation(latitude: 0, longitude: 0)
            return markers.map { ($0.id, $0.distanceToClosestLocation(from: location)) }
                .sorted { $0.1 < $1.1 }.map { $0.0 }
        }
    }
}
