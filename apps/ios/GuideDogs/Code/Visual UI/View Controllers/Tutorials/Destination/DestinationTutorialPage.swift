//
//  DestinationTutorialPage.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import UIKit
import AVFoundation

protocol DestinationTutorialPageDelegate: AnyObject {
    func getEntityKey() -> String?
    func pauseBackgroundTrack(_ completion: (() -> Void)?)
    func resumeBackgroundTrack()
    func pageComplete()
    func tutorialComplete()
}

class DestinationTutorialPage: BaseTutorialViewController {
    
    // MARK: Properties
    
    weak var delegate: DestinationTutorialPageDelegate?
    private var resolvedDestinationPOI: POI?
    private var resolvedDestinationName: String?
    private var isRefreshingEntity = false

    var destinationPOI: POI? {
        if resolvedDestinationPOI == nil {
            refreshEntity()
        }

        return resolvedDestinationPOI
    }

    var destinationName: String? {
        if resolvedDestinationName == nil {
            refreshEntity()
        }

        return resolvedDestinationName
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            await self.refreshEntityFromContract()
        }
    }

    private func refreshEntity() {
        guard let destinationKey = delegate?.getEntityKey(),
              let destinationManager = UIRuntimeProviderRegistry.providers.uiSpatialDataContext()?.destinationManager else {
            resolvedDestinationPOI = nil
            resolvedDestinationName = nil
            return
        }

        resolvedDestinationName = destinationManager.destinationNickname(forReferenceID: destinationKey) ?? resolvedDestinationPOI?.localizedName

        guard resolvedDestinationPOI == nil, !isRefreshingEntity else {
            return
        }

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            await self.refreshEntityFromContract()
        }
    }

    func refreshEntityFromContract() async {
        guard let destinationKey = delegate?.getEntityKey(),
              let destinationManager = UIRuntimeProviderRegistry.providers.uiSpatialDataContext()?.destinationManager else {
            resolvedDestinationPOI = nil
            resolvedDestinationName = nil
            return
        }

        isRefreshingEntity = true
        defer { isRefreshingEntity = false }

        resolvedDestinationPOI = await resolveDestinationPOI(destinationKey: destinationKey,
                                                             destinationManager: destinationManager)

        resolvedDestinationName = destinationManager.destinationNickname(forReferenceID: destinationKey) ?? resolvedDestinationPOI?.localizedName
    }

    func resolveDestinationPOI(destinationKey: String,
                               destinationManager: DestinationManagerProtocol) async -> POI? {
        if let destinationEntityKey = destinationManager.destinationEntityKey(forReferenceID: destinationKey),
           let destinationPOI = await DataContractRegistry.spatialRead.poi(byKey: destinationEntityKey) {
            return destinationPOI
        }

        guard let referenceEntity = await DataContractRegistry.spatialRead.referenceEntity(byID: destinationKey) else {
            return nil
        }

        if let entityKey = referenceEntity.entityKey,
           let destinationPOI = await DataContractRegistry.spatialRead.poi(byKey: entityKey) {
            return destinationPOI
        }

        return GenericLocation(ref: referenceEntity)
    }
    
    // MARK: BaseTutorialViewController Overrides
    
    override internal func play(delay: TimeInterval = 0.0, text: String, _ completion: ((Bool) -> Void)? = nil) {
        if destinationName == nil {
            refreshEntity()
        }

        var textToPlay = text
        
        if text.contains("@!destination!!") {
            textToPlay = text.replacingOccurrences(of: "@!destination!!",
                                                   with: destinationName ?? GDLocalizedString("tutorial.beacon.your_destination"))
        }
        
        super.play(delay: delay, text: textToPlay, completion)
    }
    
}
