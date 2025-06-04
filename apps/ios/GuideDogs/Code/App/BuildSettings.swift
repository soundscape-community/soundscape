//
//  BuildSettings.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

class BuildSettings {
    
    // MARK: Enums
    
    enum Configuration {
        case debug
        case adhoc
        case release
    }
    
    enum Source: String {
        case local
        case testFlight
        case appStore
        case adhoc
    }
    
    // MARK: Properties
    
    static var configuration: Configuration {
        #if DEBUG
        return .debug
        #elseif ADHOC
        return .adhoc
        #else
        return .release
        #endif
    }
    
    static var source: Source {
        switch configuration {
        case .debug:
            return .local
        case .release:
            // TestFlight builds contain an App Store receipt file named "sandboxReceipt"
            // Other sources have a receipt file named "receipt"
            if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
                appStoreReceiptURL.lastPathComponent.lowercased() == "sandboxreceipt" {
                return .testFlight
            } else {
                return .appStore
            }
        case .adhoc:
            return .adhoc
        }
    }
    
    static var isTesting: Bool {
        // By default, this argument is set by all schemes
        // when testing
        return CommandLine.arguments.contains("-TESTING")
    }
    
    // MARK: Initialization
    
    private init() { }
    
}
