//
//  GDATelemetry.swift
//  Openscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
// import AppCenterAnalytics
import Sentry

public class GDATelemetry {
    
    static var helper: TelemetryHelper?
    
    static var debugLog = false
    
    class var enabled: Bool {
        get {
            return !SettingsContext.shared.telemetryOptout
        }
        set {
            SettingsContext.shared.telemetryOptout = !newValue
            Analytics.enabled = newValue
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
        
        // Analytics.trackEvent(eventName, withProperties: propertiesToSend)
        // Represent these as Sentry breadcrumbs
        // it would be good to collect a set of values used for event name to mark as errors instead of just having everything at info
        let crum = Breadcrumb()
        crumb.data = propertiesToSend
        // crumb.data["eventName" = eventName
        crumb.message = eventName
        crumb.level = SentryLevel.info
        SentrySDK.addBreadcrumb(crumb: crumb)
    }
    
}
