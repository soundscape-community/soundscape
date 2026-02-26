//
//  BeaconActionHandler.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import SwiftUI
import SSGeo

@MainActor
struct BeaconActionHandler {
    
    ///
    /// `createMarker(detail: BeaconDetail)`
    ///
    /// parameter detail is the `BeaconDetail` object corresponding to the expected `RealmReferenceEntity`
    ///
    /// returns `UIViewController` if a view controller is returned, then the calling view or view controller should present the view controller
    ///
    static func createMarker(detail: BeaconDetail) async -> UIViewController? {
        guard let key = detail.locationDetail.beaconId else {
            return nil
        }

        guard let destinationManager = UIRuntimeProviderRegistry.providers.beaconStoreDestinationManager(),
              destinationManager.destinationKey == key,
              destinationManager.destinationIsTemporary(forReferenceID: key) else {
            return nil
        }

        let markerPOI: POI?
        if let detailEntity = detail.locationDetail.entity {
            markerPOI = detailEntity
        } else if let destinationEntityKey = destinationManager.destinationEntityKey(forReferenceID: key),
                  let destinationPOI = await DataContractRegistry.spatialRead.poi(byKey: destinationEntityKey) {
            markerPOI = destinationPOI
        } else {
            markerPOI = destinationManager.destinationPOI(forReferenceID: key)
        }

        guard let markerPOI else {
            return nil
        }

        let markerDetail = LocationDetail(entity: markerPOI)

        let config = EditMarkerConfig(detail: markerDetail,
                                      route: nil,
                                      context: "beacon_view",
                                      addOrUpdateAction: .popViewController,
                                      deleteAction: nil,
                                      leftBarButtonItemIsHidden: false)
        
        return MarkerEditViewRepresentable(config: config).makeViewController()
    }
    
    ///
    /// `callout(detail: BeaconDetail)`
    ///
    /// parameter detail is the `BeaconDetail` object corresponding to the expected `RealmReferenceEntity`
    ///
    /// queues a call out for the given audio beacon
    ///
    static func callout(detail: BeaconDetail) {
        callout(detail: detail.locationDetail)
    }
    
    ///
    /// `callout(detail: LocationDetail)`
    ///
    /// parameter detail is the `LocationDetail` object corresponding to the expected `RealmReferenceEntity`
    ///
    /// queues a call out for the given audio beacon
    ///
    static func callout(detail: LocationDetail) {
        guard let key = detail.beaconId else {
            return
        }

        if let detailEntity = detail.entity {
            processCallout(beaconID: key, destinationPOI: detailEntity)
            return
        }

        guard let destinationManager = UIRuntimeProviderRegistry.providers.beaconStoreDestinationManager(),
              destinationManager.destinationKey == key else {
            processCallout(beaconID: key, destinationPOI: nil)
            return
        }

        Task { @MainActor in
            let destinationPOI: POI?
            if let destinationEntityKey = destinationManager.destinationEntityKey(forReferenceID: key),
               let destinationEntityPOI = await DataContractRegistry.spatialRead.poi(byKey: destinationEntityKey) {
                destinationPOI = destinationEntityPOI
            } else {
                destinationPOI = destinationManager.destinationPOI(forReferenceID: key)
            }

            processCallout(beaconID: key, destinationPOI: destinationPOI)
        }
    }
    
    ///
    /// `toggleAudio`
    ///
    /// toggles the audio for the current audio beacon
    ///
    static func toggleAudio() {
        guard let destinationManager = UIRuntimeProviderRegistry.providers.beaconStoreDestinationManager() else {
            return
        }

        guard destinationManager.toggleDestinationAudio(automatic: false) else {
            // Failed to toggle audio
            return
        }
        
        let isAudioEnabled = destinationManager.isAudioEnabled
        GDATelemetry.track("beacon.toggle_audio", value: String(isAudioEnabled))
    }
    
    ///
    /// `moreInformation(detail: BeaconDetail, userLocation: SSGeoLocation)`
    ///
    /// parameters
    /// - detail is the `BeaconDetail` object corresponding to the expected `RealmReferenceEntity`
    /// - userLocation is the user's current location
    ///
    /// queues a call out for the given audio beacon
    ///
    static func moreInformation(detail: BeaconDetail, userLocation: SSGeoLocation?) {
        let dLabel = detail.labels.moreInformation(userLocation: userLocation)
        let moreInformation = dLabel.accessibilityText ?? dLabel.text
        
        // Post accessibility annoucement
        UIAccessibility.post(notification: UIAccessibility.Notification.announcement, argument: moreInformation)
        
        GDATelemetry.track("beacon.more_info")
    }
    
    ///
    /// `remove`
    ///
    /// removes the current audio beacon
    ///
    static func remove(detail: BeaconDetail) {
        if let routeDetail = detail.routeDetail {
            guard routeDetail.isGuidanceActive else {
                return
            }
            
            UIRuntimeProviderRegistry.providers.uiDeactivateCustomBehavior()
        } else {
            guard let destinationManager = UIRuntimeProviderRegistry.providers.beaconStoreDestinationManager(),
                  destinationManager.destinationKey == detail.locationDetail.beaconId else {
                // There is no beacon to clear
                return
            }

            Task { @MainActor in
                do {
                    try await destinationManager.clearDestinationAsync(logContext: "home_screen")
                    GDLogActionInfo("Clear destination")
                } catch {
                    return
                }
            }
        }
    }

    private static func processCallout(beaconID: String, destinationPOI: POI?) {
        UIRuntimeProviderRegistry.providers.uiProcessEvent(BeaconCalloutEvent(beaconId: beaconID,
                                                                               logContext: "home_screen",
                                                                               destinationPOI: destinationPOI))
        GDATelemetry.track("beacon.callout")
    }
    
}
