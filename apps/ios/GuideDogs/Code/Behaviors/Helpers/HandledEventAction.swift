//
//  HandledEventAction.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

enum HandledEventAction {
    /// The associated callouts should be played
    case playCallouts(CalloutGroup)
    
    /// The associated events should be processed
    case processEvents([Event])
    
    /// The event processor should interrupt any current callouts and optionally clear the queue
    /// - Parameters:
    ///   - playHush: When true, play the exit earcon while stopping current callouts
    ///   - clearPending: When true, pending callout groups should be dropped as well
    case interruptAndClearQueue(playHush: Bool, clearPending: Bool)
    
    /// The event was handled and no further actions are required
    case noAction
}
