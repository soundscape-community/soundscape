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
        refreshEntity()
    }

    private func refreshEntity() {
        guard delegate?.getEntityKey() != nil,
              let destinationManager = UIRuntimeProviderRegistry.providers.uiSpatialDataContext()?.destinationManager else {
            resolvedDestinationPOI = nil
            resolvedDestinationName = nil
            return
        }

        resolvedDestinationPOI = destinationManager.destinationPOI
        resolvedDestinationName = destinationManager.destinationNickname ?? resolvedDestinationPOI?.localizedName
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
