//
//  RouteParametersHandler.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation

enum RouteParametersHandlerError: Error {
    case tasksInProgress
    case resourcesNil
}

@MainActor
class RouteParametersHandler {
    
    // MARK: Typealias
    
    typealias RouteCompletion = (Result<Route, Error>) -> Void
    typealias WaypointCompletion = (Result<RouteWaypoint, Error>) -> Void
    
    // MARK: Enum
    
    private class DispatchGroupResources {
        let group = DispatchGroup()
        var success: [RouteWaypoint] = []
        var failure: Error?
    }
    
    // MARK: Properties
    
    private var current: DispatchGroupResources?
    
    var isActive: Bool {
        return current != nil
    }
    
    /**
     * Initializes a route that is being imported from a URL resource (e.g.,
     * sharing activity) and associated markers may not exist the Realm database.
     *
     * Fetches marker data for route waypoints
     *
     * - Parameters:
     *     - parameters: Imported data
     *     - completion: `Route` objects initialized from the imported data
     */
    func makeRoute(from parameters: RouteParameters, completion: @escaping RouteCompletion) {
        guard isActive == false else {
            completion(.failure(RouteParametersHandlerError.tasksInProgress))
            return
        }
        
        current = DispatchGroupResources()
        
        guard let current = current else {
            completion(.failure(RouteParametersHandlerError.resourcesNil))
            return
        }
        
        parameters.waypoints.forEach { [weak self] in
            guard let `self` = self else {
                return
            }
            
            current.group.enter()
            
            self.makeRouteWaypoint(from: $0) { result in
                switch result {
                case .success(let value): current.success.append(value)
                case .failure(let error): current.failure = error
                }
                
                current.group.leave()
            }
        }
        
        current.group.notify(queue: DispatchQueue.main, execute: { [weak self] in
            guard let self else {
                return
            }

            if let error = current.failure {
                // Failed to fetch and initialize one or more waypoints
                completion(.failure(error))
                self.current = nil
                return
            }

            Task { @MainActor in
                let firstWaypointCoordinate = await Route.firstWaypointCoordinate(for: parameters.waypoints,
                                                                                  using: DataContractRegistry.spatialRead)

                var value = Route(name: parameters.name,
                                  description: parameters.routeDescription,
                                  waypoints: current.success,
                                  firstWaypointCoordinate: firstWaypointCoordinate)

                // Save ID
                value.id = parameters.id

                // Optional Parameters

                if let pCreatedDate = parameters.createdDate {
                    value.createdDate = pCreatedDate
                }

                if let pLastUpdatedDate = parameters.lastUpdatedDate {
                    value.lastUpdatedDate = pLastUpdatedDate
                }

                if let pLastSelectedDate = parameters.lastSelectedDate {
                    value.lastSelectedDate = pLastSelectedDate
                }

                completion(.success(value))
                self.current = nil
            }
        })
    }
    
    /**
     * Initializes a waypoint from marker data that is being imported from a URL resource (e.g.,
     * sharing activity) and has not been added to the Realm database.
     *
     * Fetches marker data for route waypoints
     */
    private func makeRouteWaypoint(from parameters: RouteWaypointParameters, completion: @escaping WaypointCompletion) {
        if let marker = parameters.marker {
            marker.fetchMarker { result in
                switch result {
                case .success(let detail):
                    let value = RouteWaypoint(index: parameters.index, markerId: parameters.markerId, importedLocationDetail: detail)
                    completion(.success(value))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            Task { @MainActor in
                guard let value = await RouteWaypoint.validated(index: parameters.index,
                                                                markerId: parameters.markerId,
                                                                using: DataContractRegistry.spatialRead) else {
                    completion(.failure(ImportMarkerError.failedToFetchMarker))
                    return
                }

                completion(.success(value))
            }
        }
    }
    
}
