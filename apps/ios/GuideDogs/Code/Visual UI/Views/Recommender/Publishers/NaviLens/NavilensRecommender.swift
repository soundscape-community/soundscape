//
//  NavilensRecommender.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community.
//  Licensed under the MIT License.
//

import Foundation
import Combine
import SwiftUI
import CoreLocation
import SSGeo

/*
 * This recommender listens for location updates and queries for nearby NaviLens-enabled POIs.
 * If there is such a POI nearby the given location, the recommender publishes a corresponding
 * `NavilensRecommenderView`, else the recommender publishes a `nil` value.
 *
 */
@MainActor
class NavilensRecommender: Recommender {
    
    // Properties
    
    let publisher: CurrentValueSubject<(() -> AnyView)?, Never> = .init(nil)
    private var listeners: [AnyCancellable] = []
    
    // MARK: Initialization
    
    init() {
        self.publishCurrentValue()
        
        listeners.append(NotificationCenter.default.publisher(for: .locationUpdated)
                            // Other recommender throttles checks to every 15 seconds, but
                            // we want to know as soon as a relevant POI comes into range
                            .throttle(for: 3.0, scheduler: RunLoop.main, latest: true)
                            .receive(on: RunLoop.main)
                            .sink(receiveValue: { [weak self] _ in
                                guard let `self` = self else {
                                    return
                                }
                                
                                self.publishCurrentValue()
                            }))
    }
    
    deinit {
        listeners.cancelAndRemoveAll()
    }
    
    // MARK: Manage Publisher
    
    private func publishCurrentValue() {
        var currentValue: (() -> AnyView)?
        
        defer {
            // Publish the current value
            self.publisher.value = currentValue
        }
        
        guard let location = AppContext.shared.geolocationManager.location else {
            // Location is unknown
            return
        }
        
        // Search for NaviLens-enabled POIs within 30 meters of given location
        let navilensOnly = Filter.superCategories(orExpected: [SuperCategory.navilens])
        let navilensInRangeDistance: CLLocationDistance = 30

        guard let dataView = AppContext.shared.spatialDataContext.getDataView(for: location, searchDistance: navilensInRangeDistance) else {
            return
        }

        guard let first = dataView.pois.filtered(by: navilensOnly).sorted(by: {
            // Sort NaviLens-enabled POIs by distance
            return location.coordinate.ssGeoCoordinate.distance(to: $0.centroidCoordinate.ssGeoCoordinate) < location.coordinate.ssGeoCoordinate.distance(to: $1.centroidCoordinate.ssGeoCoordinate)
        }).first else {
            // There are no NaviLens-enabled POIs nearby
            return
        }

        if location.coordinate.ssGeoCoordinate.distance(to: first.centroidCoordinate.ssGeoCoordinate) > navilensInRangeDistance {
            // Nearest NaviLens-enabled POI is >30m away
            return
        }

        GDLogVerbose(.spatialData, String(format: "Nearest NaviLens POI is %fm away", location.coordinate.ssGeoCoordinate.distance(to: first.centroidCoordinate.ssGeoCoordinate)))

        // Update the current value
        currentValue = {
            AnyView(NavilensRecommenderView(poi: first))
        }
    }
    
}
