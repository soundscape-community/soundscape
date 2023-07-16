//
//  GDATelemetry.swift
//  Openscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
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
            if newValue {
                setup()
            }
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
        
        // Represent these as Sentry breadcrumbs
        // it would be good to collect a set of values used for event name to mark as errors instead of just having everything at info
        let crumb = Breadcrumb()
        crumb.data = propertiesToSend
        // crumb.data["eventName" = eventName
        crumb.message = eventName
        crumb.level = SentryLevel.info
        SentrySDK.addBreadcrumb(crumb)
    }
    
    class func setup() {
        if !SettingsContext.shared.telemetryOptout {
            GDLogAppInfo("Starting Sentry SDK...")
            SentrySDK.start { options in
                options.dsn = AppContext.sentryDSN
                options.debug = true
                options.sampleRate = 1.0
                options.tracesSampleRate = 1.0
                options.enableAutoPerformanceTracing = true
                options.swiftAsyncStacktraces = true
            }
        } else {
            GDLogAppInfo("**not** starting Sentry SDK; telemetry Opt-out")
        }
    }
}
