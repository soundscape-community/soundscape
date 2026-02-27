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
        guard delegate?.getEntityKey() != nil else {
            resolvedDestinationPOI = nil
            resolvedDestinationName = nil
            return
        }

        resolvedDestinationName = resolvedDestinationPOI?.localizedName

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
        guard let destinationKey = delegate?.getEntityKey() else {
            resolvedDestinationPOI = nil
            resolvedDestinationName = nil
            return
        }

        isRefreshingEntity = true
        defer { isRefreshingEntity = false }

        let destinationContext = await resolveDestinationContext(destinationKey: destinationKey)
        resolvedDestinationPOI = destinationContext.poi
        resolvedDestinationName = destinationContext.nickname ?? destinationContext.poi?.localizedName
    }

    func resolveDestinationContext(destinationKey: String) async -> (poi: POI?, nickname: String?) {
        guard let referenceEntity = await DataContractRegistry.spatialRead.referenceEntity(byID: destinationKey) else {
            return (nil, nil)
        }

        let nickname = referenceEntity.nickname
        if let entityKey = referenceEntity.entityKey,
           let destinationPOI = await DataContractRegistry.spatialRead.poi(byKey: entityKey) {
            return (destinationPOI, nickname)
        }

        return (GenericLocation(ref: referenceEntity), nickname)
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
