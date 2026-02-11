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
    private var entityLookupTask: Task<Void, Never>?
    private var resolvedEntity: ReferenceEntity?
    
    var entity: ReferenceEntity? {
        return resolvedEntity
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshEntity()
    }

    private func refreshEntity() {
        entityLookupTask?.cancel()

        guard let key = delegate?.getEntityKey() else {
            resolvedEntity = nil
            return
        }

        entityLookupTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            resolvedEntity = await DataContractRegistry.spatialRead.referenceEntity(byEntityKey: key)
        }
    }

    deinit {
        entityLookupTask?.cancel()
    }
    
    // MARK: BaseTutorialViewController Overrides
    
    override internal func play(delay: TimeInterval = 0.0, text: String, _ completion: ((Bool) -> Void)? = nil) {
        if entity == nil {
            refreshEntity()
        }

        var textToPlay = text
        
        if text.contains("@!destination!!") {
            textToPlay = text.replacingOccurrences(of: "@!destination!!", with: entity?.name ?? GDLocalizedString("tutorial.beacon.your_destination"))
        }
        
        super.play(delay: delay, text: textToPlay, completion)
    }
    
}
