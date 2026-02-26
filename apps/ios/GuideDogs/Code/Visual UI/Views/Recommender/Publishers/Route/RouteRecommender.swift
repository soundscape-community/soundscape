//
//  RouteRecommender.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import Combine
import SwiftUI
import CoreLocation
import SSGeo

/*
 * This recommender listens for location updates and queries for nearby routes.
 * If there is a route nearby the given location, the recommender publishes a corresponding
 * `RouteRecommenderView`, else the recommender publishes a `nil` value.
 *
 */
@MainActor
class RouteRecommender: Recommender {
    
    // Properties
    
    let publisher: CurrentValueSubject<(() -> AnyView)?, Never> = .init(nil)
    private var listeners: [AnyCancellable] = []
    private var publishTask: Task<Void, Never>?
    
    // MARK: Initialization
    
    init() {
        self.refreshCurrentValue()
        
        listeners.append(NotificationCenter.default.publisher(for: .locationUpdated)
                            // Location updates occur more frequently than required by the recommender
                            // Throttle updates to once every 15.0 seconds
                            .throttle(for: 15.0, scheduler: RunLoop.main, latest: true)
                            .receive(on: RunLoop.main)
                            .sink(receiveValue: { [weak self] _ in
                                guard let `self` = self else {
                                    return
                                }
                                
                                self.refreshCurrentValue()
                            }))
    }
    
    deinit {
        listeners.cancelAndRemoveAll()
        publishTask?.cancel()
    }
    
    // MARK: Manage Publisher
    
    private func refreshCurrentValue() {
        publishTask?.cancel()
        publishTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            await self.publishCurrentValue()
        }
    }

    private func publishCurrentValue() async {
        var currentValue: (() -> AnyView)?
        
        defer {
            if !Task.isCancelled {
                // Publish the current value
                self.publisher.value = currentValue
            }
        }
        
        guard let location = UIRuntimeProviderRegistry.providers.uiCurrentUserLocation() else {
            // Location is unknown
            return
        }
        
        // Search for routes near the given location and sort
        // by `lastSelectedDate`.
        let nearby = await DataContractRegistry.spatialRead.routes()
            .compactMap({ route -> (route: Route, distance: CLLocationDistance, selected: Date, created: Date)? in
                guard let wLocation = route.firstWaypointLocation else {
                    return nil
                }

                let distance = location.coordinate.ssGeoCoordinate.distance(to: wLocation.coordinate.ssGeoCoordinate)
                guard distance <= 5000 else {
                    return nil
                }
                
                return (route: route, distance: distance, selected: route.lastSelectedDate, created: route.createdDate)
            })
            .sorted(by: {
                if $0.distance != $1.distance {
                    // Sort by distance to user's current location
                    return $0.distance < $1.distance
                }
                
                if $0.selected != $1.selected {
                    // Sort by most recently selected
                    return $0.selected > $1.selected
                }
                
                // Finally, sort by most recently created
                return $0.created > $1.created
            })
            .compactMap({ return $0.route })
        
        guard let first = nearby.first else {
            // There are no nearby routes
            return
        }
        
        let detail = RouteDetail(source: .database(id: first.id))
        
        // Update the current value
        currentValue = {
            AnyView(RouteRecommenderView(route: detail))
        }
    }
    
}
