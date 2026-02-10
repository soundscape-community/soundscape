//
//  CloudKeyValueStore+Routes.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import UIKit

// MARK: Storing Routes

/// Each route entity is stored in the cloud key value store as it's own top-level object.
/// This should minimize risk of data loss when using a top level array that contain all objects.
@MainActor
extension CloudKeyValueStore {
    
    private static var errorAlert: UIAlertController?
    
    // MARK: Constants
    
    /// route objects will be top-level key-value objects with a key format of "route.object_id"
    private static let routeKeyPrefix = "routes"
    
    // MARK: Containment
    
    private var routeKeys: [String] {
        return allKeys.filter { $0.hasPrefix(CloudKeyValueStore.routeKeyPrefix) }
    }
    
    private var routeParametersObjects: [RouteParameters] {
        return routeKeys.compactMap { routeParameters(forKey: $0) }
    }
    
    private func routeParameters(forKey key: String) -> RouteParameters? {
        guard let data = object(forKey: key) as? Data else { return nil }
        
        let decoder = JSONDecoder()
        let routeParameters: RouteParameters
        do {
            routeParameters = try decoder.decode(RouteParameters.self, from: data)
        } catch {
            GDLogCloudInfo("Could not decode route with key: \(key)")
            return nil
        }
        
        return routeParameters
    }
    
    // MARK: Individual Set/Get
    
    /// Returns "route.object_id"
    private static func key(forRoute route: Route) -> String {
        return CloudKeyValueStore.routeKeyPrefix + "." + route.id
    }

    /// Returns "route.object_id"
    private static func key(forRouteID routeID: String) -> String {
        return CloudKeyValueStore.routeKeyPrefix + "." + routeID
    }
    
    /// Returns "object_id" from "route.object_id"
    private static func id(forRoute routeKey: String) -> String {
        return routeKey.replacingOccurrences(of: CloudKeyValueStore.routeKeyPrefix + ".", with: "")
    }
    
    func store(route: Route) {
        if let routeParameters = RouteParameters(route: route, context: .backup) {
            store(routeParameters: routeParameters)
        } else {
            GDLogCloudInfo("Failed to initialize route")
            Task { @MainActor in
                GDATelemetry.track("route_backup.error.parameters_failed_to_initialize")
            }
        }
    }
    
    func update(route: Route) {
        // For iCloud key-value store we override the current value
        store(route: route)
    }
    
    func remove(route: Route) {
        removeObject(forKey: CloudKeyValueStore.key(forRoute: route))
    }
    
    // MARK: Bulk Set/Get
    
    /// Make sure to call this after syncing markers
    func syncRoutes(reason: CloudKeyValueStoreChangeReason, changedKeys: [String]? = nil) {
        Task { @MainActor in
            await syncRoutesAsync(reason: reason, changedKeys: changedKeys)
        }
    }

    func syncRoutesAsync(reason: CloudKeyValueStoreChangeReason, changedKeys: [String]? = nil) async {
        await importRouteChanges(changedKeys: changedKeys)

        if reason == .initialSync || reason == .accountChanged {
            await store()
        }
    }

    private func importRouteChanges(changedKeys: [String]? = nil) async {
        var routeParametersObjects = self.routeParametersObjects
        
        // If there are changed keys, we only add/update those objects.
        // If there no changed keys, such as an initial sync or account change we add/update all objects.
        if let changedKeys = changedKeys {
            // Discard irrelevant keys
            var changedKeys = changedKeys.filter { $0.hasPrefix(CloudKeyValueStore.routeKeyPrefix) }
            
            // Discard deleted keys
            changedKeys = changedKeys.filter { allKeys.contains($0) }
            
            // Transform to object ids ("route.object_id" -> "object_id")
            let changedIds = changedKeys.map { CloudKeyValueStore.id(forRoute: $0) }
            
            // Filter only changed objects
            routeParametersObjects = routeParametersObjects.filter({ (routeParameters) -> Bool in
                return changedIds.contains(routeParameters.id)
            })
        }

        var routeParametersNeedingUpdate: [RouteParameters] = []
        for routeParameters in routeParametersObjects where await shouldUpdateLocalRoute(withRouteParameters: routeParameters) {
            routeParametersNeedingUpdate.append(routeParameters)
        }

        await importRouteChanges(routeParametersObjects: routeParametersNeedingUpdate)
    }
    
    /// Import route parameters from cloud store to database
    private func importRouteChanges(routeParametersObjects: [RouteParameters]) async {
        for routeParameters in routeParametersObjects {
            importChanges(routeParameters: routeParameters)
        }

        await notifyOfInvalidRoutesIfNeeded(routeParametersObjects: routeParametersObjects)
    }
    
    private func importChanges(routeParameters: RouteParameters) {
        let route = Route(from: routeParameters)
        importChanges(route: route)
    }
    
    /// Import route entities from cloud store to database
    private func importChanges(route: Route) {
        autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else { return }
            
            do {
                try database.write {
                    database.add(route, update: .modified)
                }
                GDLogCloudInfo("Imported route with id: \(route.id), name: \(route.name)")
            } catch {
                GDLogCloudInfo("Could not import route with id: \(route.id), name: \(route.name), error: \(error)")
            }
        }
    }
    
    /// Store route entities from database to cloud store
    private func store() async {
        let localRouteParametersObjects = await DataContractRegistry.spatialRead.routeParametersForBackup()

        for routeParameters in localRouteParametersObjects where shouldUpdateCloudRoute(withLocalRouteParameters: routeParameters) {
            store(routeParameters: routeParameters)
        }
    }

    private func store(routeParameters: RouteParameters) {
        let encoder = JSONEncoder()
        let data: Data

        do {
            data = try encoder.encode(routeParameters)
        } catch {
            GDLogCloudInfo("Could not encode route with id: \(routeParameters.id), name: \(routeParameters.name)")
            return
        }

        set(object: data, forKey: CloudKeyValueStore.key(forRouteID: routeParameters.id))
    }
    
}

// MARK: Helpers

@MainActor
extension CloudKeyValueStore {
    
    func notifyOfInvalidRoutesIfNeeded(routeParametersObjects: [RouteParameters]) async {
        guard FirstUseExperience.didComplete(.oobe) else {
            // If there is an error, do not display it until after onboarding has completed
            // Save the parameters
            pendingRouteErrorNotifications.append(contentsOf: routeParametersObjects)
            return
        }
        
        guard CloudKeyValueStore.errorAlert == nil else {
            return
        }

        var invalidRoutes: [RouteParameters] = []
        for routeParameters in routeParametersObjects where await !CloudKeyValueStore.isValid(routeParameters: routeParameters) {
            invalidRoutes.append(routeParameters)
        }
        
        guard !invalidRoutes.isEmpty else {
            return
        }
        
        let invalidRouteNames = invalidRoutes.map { $0.name }.joined(separator: "\n")

        CloudKeyValueStore.errorAlert = ErrorAlerts.buildGeneric(title: GDLocalizedString("routes.import.alert.title"),
                                                                 message: GDLocalizedString("routes.import.alert.message") + "\n\n" + invalidRouteNames,
                                                                 dismissHandler: { _ in
            CloudKeyValueStore.errorAlert = nil
        })
        
        guard let window = UIApplication.shared.windows.first(where: \.isKeyWindow),
              let rootViewController = window.rootViewController,
              let alert = CloudKeyValueStore.errorAlert else {
                  return
              }
        
        rootViewController.present(alert, animated: true, completion: nil)
        
        Task { @MainActor in
            GDATelemetry.track("route_backup.error.marker_deleted")
        }
    }
    
    /// Check if there are markers in the imported route that does not exist in as reference entities
    private static func isValid(routeParameters: RouteParameters) async -> Bool {
        let markerIds = routeParameters.waypoints.map { $0.markerId }
        
        for markerId in markerIds where await DataContractRegistry.spatialRead.referenceMetadata(byID: markerId) == nil {
            GDLogCloudInfo("Route with id: \(routeParameters.id), name: \(routeParameters.name), is missing a marker with id: \(markerId)")
            return false
        }
        
        return true
    }
    
    private func shouldUpdateLocalRoute(withRouteParameters routeParameters: RouteParameters) async -> Bool {
        // True if local database does not contain the cloud entity
        guard let localRouteMetadata = await DataContractRegistry.spatialRead.routeMetadata(byKey: routeParameters.id) else { return true }
        
        return CloudKeyValueStore.shouldUpdate(localRouteMetadata: localRouteMetadata, withRouteParameters: routeParameters)
    }

    private static func shouldUpdate(localRouteMetadata: RouteReadMetadata, withRouteParameters routeParameters: RouteParameters) -> Bool {
        // False if the cloud entity does not have a `lastUpdatedDate` property
        guard let otherLastUpdated = routeParameters.lastUpdatedDate else { return false }

        // True if local entity does not have a `lastUpdatedDate` property
        guard let selfLastUpdated = localRouteMetadata.lastUpdatedDate else { return true }

        // True only if the cloud entity is newer
        return otherLastUpdated > selfLastUpdated
    }
    
    private func shouldUpdateCloudRoute(withLocalRouteParameters localRouteParameters: RouteParameters) -> Bool {
        // True if the cloud does not contain the local entity
        let key = CloudKeyValueStore.key(forRouteID: localRouteParameters.id)
        guard let cloudRouteParameters = self.routeParameters(forKey: key) else { return true }

        return cloudRouteParameters.shouldUpdate(withRouteParameters: localRouteParameters)
    }
    
}

extension RouteParameters {
    
    fileprivate func shouldUpdate(withRouteParameters routeParameters: RouteParameters) -> Bool {
        // True if this entity does not have a `lastUpdatedDate` property
        guard let selfLastUpdated = self.lastUpdatedDate else { return true }

        // False if the other entity does not have a `lastUpdatedDate` property
        guard let otherLastUpdated = routeParameters.lastUpdatedDate else { return false }

        // True only if the last update date of the other entity is newer
        return otherLastUpdated > selfLastUpdated
    }
    
}
