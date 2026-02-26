//
//  DestinationTutorialInfoPage.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import UIKit
import CoreLocation

class DestinationTutorialInfoPage: DestinationTutorialPage {
    
    // MARK: Content Strings
    
    let mobilitySkills = GDLocalizedString("tutorial.beacons.text.MobilitySkills")
    let automaticCallout = GDLocalizedString("tutorial.beacons.text.AutomaticCallout")
    let homeScreen = GDLocalizedString("tutorial.beacons.text.HomeScreen")
    
    // MARK: Methods
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        pageTextLabel.text = mobilitySkills
        
        UIRuntimeProviderRegistry.providers.uiToggleDestinationAudio()
        
        self.delegate?.resumeBackgroundTrack()
        
        play(delay: 1.0, text: mobilitySkills) { [weak self] (finished) in
            guard finished, let `self` = self else {
                return
            }
            
            self.play(delay: 1.0, text: self.automaticCallout) { [weak self] (finished) in
                guard finished, let `self` = self else {
                    return
                }
                
                self.delegate?.pauseBackgroundTrack({ [weak self] in
                    self?.playCallout()
                })
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        pageFinished = true
    }
    
    private func playCallout() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard let destinationPOI = await self.resolveDestinationPOIForCallout(),
                  let location = UIRuntimeProviderRegistry.providers.uiCurrentUserLocation() else {
                // Return if destination could not be retrieved
                return
            }

            let distance = destinationPOI.distanceToClosestLocation(from: location)
            let loc = destinationPOI.closestLocation(from: location, useEntranceIfAvailable: true)
            let callout = LanguageFormatter.string(from: distance,
                                                   accuracy: location.horizontalAccuracy,
                                                   name: GDLocalizedString("beacon.generic_name"))

            let finished = await self.tutorialCalloutPlayer.play(text: callout,
                                                                 glyph: StaticAudioEngineAsset.poiSense,
                                                                 location: loc,
                                                                 logContext: "tutorial.destination.distance")
            guard finished else {
                return
            }

            self.delegate?.resumeBackgroundTrack()
            self.calloutCompleted()
        }
    }

    private func resolveDestinationPOIForCallout() async -> POI? {
        guard let destinationKey = delegate?.getEntityKey(),
              let destinationManager = UIRuntimeProviderRegistry.providers.uiSpatialDataContext()?.destinationManager else {
            return destinationPOI
        }

        if let destinationEntityKey = destinationManager.destinationEntityKey(forReferenceID: destinationKey),
           let resolvedPOI = await DataContractRegistry.spatialRead.poi(byKey: destinationEntityKey) {
            return resolvedPOI
        }

        return destinationManager.destinationPOI(forReferenceID: destinationKey) ?? destinationPOI
    }
    
    private func calloutCompleted() {
        play(text: homeScreen, { [weak self] (finished) in
            guard finished else {
                return
            }
            
            self?.delegate?.pageComplete()
        })
    }
    
}
