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
    var currentDestinationPOI: POI? { destinationPOI }
    
    private let publisher: Heading
    private var heading: CLLocationDegrees?
    private let location: CLLocation?
    private var destinationPOI: POI?
    private var destinationEntityKey: String?
    private var destinationResolutionTask: Task<Void, Never>?
    private var listeners: [AnyCancellable] = []
    
    // MARK: Initialization
    
    init() {
        publisher = UIRuntimeProviderRegistry.providers.uiPresentationHeading()
        
        // Save initial values
        heading = publisher.value
        location = UIRuntimeProviderRegistry.providers.uiCurrentUserLocation()
        if let destinationManager = UIRuntimeProviderRegistry.providers.uiSpatialDataContext()?.destinationManager,
           let destinationKey = destinationManager.destinationKey {
            destinationEntityKey = nil
            resolveDestinationPOI(forReferenceID: destinationKey, destinationManager: destinationManager)
        }
        
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
                self.destinationPOI = notification.userInfo?[DestinationManager.Keys.destinationPOI] as? POI
                self.destinationEntityKey = notification.userInfo?[DestinationManager.Keys.destinationEntityKey] as? String

                if self.destinationPOI == nil {
                    self.resolveDestinationPOI(forReferenceID: key, destinationManager: destinationManager)
                } else {
                    self.destinationResolutionTask?.cancel()
                }
            } else {
                self.destinationResolutionTask?.cancel()
                self.destinationPOI = nil
                self.destinationEntityKey = nil
            }
            
            self.updateCurrentValues()
        }))
    }
    
    deinit {
        destinationResolutionTask?.cancel()

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

        guard let destinationManager = UIRuntimeProviderRegistry.providers.uiSpatialDataContext()?.destinationManager else {
            return
        }

        guard let bearingToLocation = destinationPOI?.bearingToClosestLocation(from: location) else {
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

    private func resolveDestinationPOI(forReferenceID id: String,
                                       destinationManager: DestinationManagerProtocol) {
        destinationResolutionTask?.cancel()
        let destinationEntityKey = self.destinationEntityKey

        destinationResolutionTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            if let destinationEntityKey,
               let destinationPOI = await DataContractRegistry.spatialRead.poi(byKey: destinationEntityKey) {
                guard !Task.isCancelled, destinationManager.destinationKey == id else {
                    return
                }

                self.destinationPOI = destinationPOI
                self.updateCurrentValues()
                return
            }

            guard !Task.isCancelled, destinationManager.destinationKey == id else {
                return
            }

            self.destinationPOI = await resolveDestinationPOIContractFallback(forReferenceID: id)
            self.updateCurrentValues()
        }
    }

    private func resolveDestinationPOIContractFallback(forReferenceID id: String) async -> POI? {
        guard let referenceEntity = await DataContractRegistry.spatialRead.referenceEntity(byID: id) else {
            return nil
        }

        if let entityKey = referenceEntity.entityKey,
           let destinationPOI = await DataContractRegistry.spatialRead.poi(byKey: entityKey) {
            return destinationPOI
        }

        return GenericLocation(ref: referenceEntity)
    }
    
}
