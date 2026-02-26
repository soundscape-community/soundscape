//
//  InteractiveBeaconViewModel.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import Combine

@MainActor
class InteractiveBeaconViewModel: ObservableObject {
    
    enum Orientation {
        case ahead
        case behind
        case other
    }
    
    // MARK: Properties
    
    @Published var isBeaconInBounds = false
    @Published var bearingToBeacon = 0.0
    @Published var beaconOrientation: Orientation = .other
    
    private let publisher: Heading
    private var heading: CLLocationDegrees?
    private let location: CLLocation?
    private var destinationPOI: POI?
    private var listeners: [AnyCancellable] = []
    
    // MARK: Initialization
    
    init() {
        publisher = UIRuntimeProviderRegistry.providers.uiPresentationHeading()
        
        // Save initial values
        heading = publisher.value
        location = UIRuntimeProviderRegistry.providers.uiCurrentUserLocation()
        destinationPOI = UIRuntimeProviderRegistry.providers.uiSpatialDataContext()?.destinationManager.destinationPOI
        
        updateCurrentValues()
        
        publisher.onHeadingDidUpdate { [weak self] heading in
            guard let `self` = self else {
                return
            }
            
            self.heading = heading?.value
            
            self.updateCurrentValues()
        }
        
        listeners.append(NotificationCenter.default.publisher(for: .destinationChanged)
                            .receive(on: DispatchQueue.main)
                            .sink(receiveValue: { [weak self] notification in
            guard let `self` = self else {
                return
            }

            if let key = notification.userInfo?[DestinationManager.Keys.destinationKey] as? String,
               let destinationManager = UIRuntimeProviderRegistry.providers.uiSpatialDataContext()?.destinationManager,
               destinationManager.destinationKey == key {
                self.destinationPOI = (notification.userInfo?[DestinationManager.Keys.destinationPOI] as? POI) ?? destinationManager.destinationPOI
            } else {
                self.destinationPOI = nil
            }
            
            self.updateCurrentValues()
        }))
    }
    
    deinit {
        // Remove handler
        publisher.onHeadingDidUpdate(nil)
        
        // Remove listeners
        listeners.cancelAndRemoveAll()
    }
    
    private func updateCurrentValues() {
        guard let location = location else {
            return
        }
        
        guard let heading = heading else {
            return
        }
        
        guard let destinationManager = UIRuntimeProviderRegistry.providers.uiSpatialDataContext()?.destinationManager,
              let bearingToLocation = (destinationPOI ?? destinationManager.destinationPOI)?.bearingToClosestLocation(from: location) else {
            return
        }
        
        bearingToBeacon = heading.bearing(to: bearingToLocation)
        isBeaconInBounds = destinationManager.isBeaconInBounds
        
        if bearingToBeacon > 345.0 || bearingToBeacon < 15.0 {
            beaconOrientation = .ahead
        } else if bearingToBeacon > 165.0 && bearingToBeacon < 195.0 {
            beaconOrientation = .behind
        } else {
            beaconOrientation = .other
        }
    }
    
}
