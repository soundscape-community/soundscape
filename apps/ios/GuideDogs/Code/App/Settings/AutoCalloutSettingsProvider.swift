//
//  AutoCalloutSettingsProvider.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

protocol AutoCalloutSettingsProvider: AnyObject {
    ///Whether or not callouts are enabled globally
    ///false - no automatic callouts generated
    var automaticCalloutsEnabled: Bool { get set }
    /// Whether callout sound effects (earcons) should play before spoken callouts.
    /// When false, only the spoken text will be played with no preceding audio cue.
    var calloutsEarconEnabled: Bool { get set }
        
    /// Whether delays should be inserted between automatic callouts.
    /// When false, callouts will play back-to-back with no pause between them.
    var calloutsDelayEnabled: Bool { get set }
    
    /// Whether place callouts are enabled
    var placeSenseEnabled: Bool { get set }
    
    /// Whether landmark callouts are enabled
    var landmarkSenseEnabled: Bool { get set }
    
    /// Whether mobility callouts are enabled (intersections, transit info, etc.)
    var mobilitySenseEnabled: Bool { get set }
    
    /// Whether information callouts are enabled/
    var informationSenseEnabled: Bool { get set }
    
    /// Whether safety callouts are enabled
    var safetySenseEnabled: Bool { get set }
    
    /// Whether intersection callouts are enabled
    var intersectionSenseEnabled: Bool { get set }
    
    /// Whether destination/beacon callouts are enabled
    var destinationSenseEnabled: Bool { get set }
}
