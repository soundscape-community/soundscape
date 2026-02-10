//
//  CloudKeyValueStore+Markers.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

// MARK: Storing Reference Entities

/// Each reference entity is stored in the cloud key value store as it's own top-level object.
/// This should minimize risk of data loss when using a top level array that contain all objects.
@MainActor
extension CloudKeyValueStore {
    
    // Types
    
    typealias CompletionHandler = (() -> Void)?
    
    // MARK: Constants
    
    /// Marker objects will be top-level key-value objects with a key format of "marker.object_id"
    private static let markerKeyPrefix = "marker"
    
    // MARK: Containment
    
    private var markerKeys: [String] {
        return allKeys.filter { $0.hasPrefix(CloudKeyValueStore.markerKeyPrefix) }
    }
    
    private var markerParametersObjects: [MarkerParameters] {
        return markerKeys.compactMap { markerParameters(forKey: $0) }
    }
    
    private func markerParameters(forKey key: String) -> MarkerParameters? {
        guard let data = object(forKey: key) as? Data else { return nil }
        
        let decoder = JSONDecoder()
        let markerParameters: MarkerParameters
        do {
            markerParameters = try decoder.decode(MarkerParameters.self, from: data)
        } catch {
            GDLogCloudInfo("Could not decode marker with with key: \(key)")
            return nil
        }
        
        return markerParameters
    }
    
    // MARK: Individual Set/Get
    
    /// Returns "marker.object_id"
    private static func key(for referenceEntity: RealmReferenceEntity) -> String {
        return CloudKeyValueStore.markerKeyPrefix + "." + referenceEntity.id
    }

    /// Returns "marker.object_id"
    private static func key(forReferenceEntityID id: String) -> String {
        return CloudKeyValueStore.markerKeyPrefix + "." + id
    }
    
    /// Returns "object_id" from "marker.object_id"
    private static func id(for referenceEntityKey: String) -> String {
        return referenceEntityKey.replacingOccurrences(of: CloudKeyValueStore.markerKeyPrefix + ".", with: "")
    }
    
    func store(referenceEntity: RealmReferenceEntity) {
        if let markerParameters = MarkerParameters(marker: referenceEntity) {
            store(markerParameters: markerParameters)
        } else {
            GDLogCloudInfo("Failed to initialize marker parameters")
            Task { @MainActor in
                GDATelemetry.track("marker_backup.error.parameters_failed_to_initialize")
            }
        }
    }
    
    func update(referenceEntity: RealmReferenceEntity) {
        // For iCloud key-value store we override the current value
        store(referenceEntity: referenceEntity)
    }
    
    func remove(referenceEntity: RealmReferenceEntity) {
        removeObject(forKey: CloudKeyValueStore.key(for: referenceEntity))
    }
    
    // MARK: Bulk Set/Get
    
    func syncReferenceEntities(reason: CloudKeyValueStoreChangeReason, changedKeys: [String]? = nil, completion: CompletionHandler = nil) {
        Task { @MainActor in
            await syncReferenceEntitiesAsync(reason: reason, changedKeys: changedKeys)
            completion?()
        }
    }

    func syncReferenceEntitiesAsync(reason: CloudKeyValueStoreChangeReason, changedKeys: [String]? = nil) async {
        await importReferenceEntityChanges(changedKeys: changedKeys)

        if reason == .initialSync || reason == .accountChanged {
            await store()
        }
    }

    private func importReferenceEntityChanges(changedKeys: [String]? = nil) async {
        var markerParametersObjects = self.markerParametersObjects
        
        // If there are changed keys, we only add/update those objects.
        // If there no changed keys, such as an initial sync or account change we add/update all objects.
        if let changedKeys = changedKeys {
            // Discard irrelevant keys
            var changedKeys = changedKeys.filter { $0.hasPrefix(CloudKeyValueStore.markerKeyPrefix) }
            
            // Discard deleted keys
            changedKeys = changedKeys.filter { allKeys.contains($0) }
            
            // Transform to object ids ("marker.object_id" -> "object_id")
            let changedIds = changedKeys.map { CloudKeyValueStore.id(for: $0) }
            
            // Filter only changed objects
            markerParametersObjects = markerParametersObjects.filter({ (markerParameters) -> Bool in
                guard let id = markerParameters.id else { return false }
                return changedIds.contains(id)
            })
        }

        var markerParametersNeedingUpdate: [MarkerParameters] = []
        for markerParameters in markerParametersObjects where await shouldUpdateLocalReferenceEntity(withMarkerParameters: markerParameters) {
            markerParametersNeedingUpdate.append(markerParameters)
        }

        await importReferenceEntityChanges(markerParametersObjects: markerParametersNeedingUpdate)
    }
    
    /// Import marker parameters from cloud store to database
    private func importReferenceEntityChanges(markerParametersObjects: [MarkerParameters]) async {
        for markerParameters in markerParametersObjects {
            await importChanges(markerParameters: markerParameters)
        }
    }

    private func importChanges(markerParameters: MarkerParameters) async {
        // We load the underlying entity which either finds it in the local database,
        // or initializes and store a new underlying entity
        let result: Result<POI, Error> = await withCheckedContinuation { continuation in
            markerParameters.location.fetchEntity { result in
                continuation.resume(returning: result)
            }
        }

        switch result {
        case .success(let entity):
            if let referenceEntity = RealmReferenceEntity(markerParameters: markerParameters, entity: entity) {
                importChanges(referenceEntity: referenceEntity)
            } else {
                GDLogCloudInfo("Error initializing `RealmReferenceEntity` object for marker with id: \(markerParameters.id ?? "none")")
            }
        case .failure(let error):
            GDLogCloudInfo("Error loading underlying entity: \(error)")
        }
    }
    
    /// Import reference entities from cloud store to database
    private func importChanges(referenceEntity: RealmReferenceEntity) {
        autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else { return }
            
            do {
                try database.write {
                    database.add(referenceEntity, update: .modified)
                }
                GDLogCloudInfo("Imported reference entity with id: \(referenceEntity.id), name: \(referenceEntity.name)")
            } catch {
                GDLogCloudInfo("Could not import reference entity with id: \(referenceEntity.id), name: \(referenceEntity.name), error: \(error)")
            }
        }
    }
    
    /// Store reference entities from database to cloud store
    private func store() async {
        let localMarkerParametersObjects = await DataContractRegistry.spatialRead.markerParametersForBackup()

        for markerParameters in localMarkerParametersObjects where shouldUpdateCloudReferenceEntity(withLocalMarkerParameters: markerParameters) {
            store(markerParameters: markerParameters)
        }
    }

    private func store(markerParameters: MarkerParameters) {
        guard let id = markerParameters.id else {
            GDLogCloudInfo("Could not encode marker with id: none, nickname: \(markerParameters.nickname ?? "none")")
            return
        }

        let encoder = JSONEncoder()
        let data: Data

        do {
            data = try encoder.encode(markerParameters)
        } catch {
            GDLogCloudInfo("Could not encode marker with id: \(id), nickname: \(markerParameters.nickname ?? "none")")
            return
        }

        set(object: data, forKey: CloudKeyValueStore.key(forReferenceEntityID: id))
    }
}

// MARK: Helpers

@MainActor
extension CloudKeyValueStore {
    
    private func shouldUpdateLocalReferenceEntity(withMarkerParameters markerParameters: MarkerParameters) async -> Bool {
        // False if no id
        guard let id = markerParameters.id else { return false }
        
        // True if local database does not contain the cloud entity
        guard let localReferenceMetadata = await DataContractRegistry.spatialRead.referenceMetadata(byID: id) else { return true }
        
        return CloudKeyValueStore.shouldUpdate(localReferenceMetadata: localReferenceMetadata, withMarkerParameters: markerParameters)
    }
    
    private func shouldUpdateCloudReferenceEntity(withLocalMarkerParameters localMarkerParameters: MarkerParameters) -> Bool {
        guard let localID = localMarkerParameters.id else { return false }

        // True if the cloud does not contain the local entity
        let key = CloudKeyValueStore.key(forReferenceEntityID: localID)
        guard let cloudMarkerParameters = self.markerParameters(forKey: key) else { return true }

        return cloudMarkerParameters.shouldUpdate(withMarkerParameters: localMarkerParameters)
    }

    private static func shouldUpdate(localReferenceMetadata: ReferenceReadMetadata, withMarkerParameters markerParameters: MarkerParameters) -> Bool {
        // False if the cloud entity does not have a `lastUpdatedDate` property
        guard let otherLastUpdated = markerParameters.lastUpdatedDate else { return false }

        // True if local entity does not have a `lastUpdatedDate` property
        guard let selfLastUpdated = localReferenceMetadata.lastUpdatedDate else { return true }

        // True only if the cloud entity is newer
        return otherLastUpdated > selfLastUpdated
    }
    
}

extension MarkerParameters {
    
    fileprivate func shouldUpdate(withMarkerParameters markerParameters: MarkerParameters) -> Bool {
        // True if this entity does not have a `lastUpdatedDate` property
        guard let selfLastUpdated = self.lastUpdatedDate else { return true }

        // False if the other entity does not have a `lastUpdatedDate` property
        guard let otherLastUpdated = markerParameters.lastUpdatedDate else { return false }

        // True only if the last update date of the other entity is newer
        return otherLastUpdated > selfLastUpdated
    }
    
}
