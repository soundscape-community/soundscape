//
//  GDATelemetry.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//
// This is just a stub, MS used AppCenter which is being depricated.

import Foundation

public class GDATelemetry {
    
    static var helper: TelemetryHelper?
    
    static var debugLog = false
    
    class var enabled: Bool {
        get {
            return !SettingsContext.shared.telemetryOptout
        }
        set {
            SettingsContext.shared.telemetryOptout = !newValue
                    }
    }
    
    class func trackScreenView(_ screenName: String, with properties: [String: String]? = nil) {
        var propertiesToSend = properties ?? [:]
        propertiesToSend["screen_name"] = screenName

        track("screen_view", with: propertiesToSend)
    }
    
    class func track(_ eventName: String, value: String) {
        track(eventName, with: ["value": value])
    }
    
    class func track(_ eventName: String, with properties: [String: String]? = nil) {
        var propertiesToSend = properties ?? [:]
        propertiesToSend["user_id"] = SettingsContext.shared.clientId
        
        // Add default event properties
        if let helper = helper {
            propertiesToSend = propertiesToSend.merging(helper.eventSnapshot) { (current, _) in current }
        }
        
        if debugLog {
            print("[TEL] Event tracked: \(eventName)" + (propertiesToSend.isEmpty ? "" : " \(propertiesToSend)"))
        }
    }
    
}
