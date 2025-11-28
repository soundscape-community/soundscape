//
//  TutorialCalloutPlayer.swift
//  Soundscape
//
//  Introduces an async helper for tutorial callouts so flows can await
//  completion via the CalloutCoordinator instead of closure pyramids.
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation

@MainActor
final class TutorialCalloutPlayer {

    func play(text: String,
              glyph: StaticAudioEngineAsset? = nil,
              compass: CLLocationDirection? = nil,
              direction: CLLocationDirection? = nil,
              location: CLLocation? = nil,
              logContext: String = "tutorial.announcement") async -> Bool {
        let callout: CalloutProtocol

        if let location = location {
            callout = StringCallout(.system, text, glyph: glyph, location: location)
        } else if let compass = compass {
            callout = StringCallout(.system, text, glyph: glyph, position: compass)
        } else if let direction = direction {
            callout = RelativeStringCallout(.system, text, glyph: glyph, position: direction)
        } else {
            callout = StringCallout(.system, text, glyph: glyph)
        }

        let group = CalloutGroup([callout], action: .interruptAndClear, logContext: logContext)
        return await AppContext.shared.eventProcessor.playCallouts(group)
    }
}
