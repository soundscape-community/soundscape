//
//  UniversalLinkComponents.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

struct UniversalLinkComponents {
    
    // MARK: Properties
    
    // the base URL for sharing deeplinks in the app
    // This should be in your associated domains entitlement;
    private static let host = "https://share.soundscape.services"

    let pathComponents: UniversalLinkPathComponents
    let queryItems: [URLQueryItem]?
    
    /// The generated share URL
    var url: URL? {
        let host = UniversalLinkComponents.host
        let path = pathComponents.versionedPath

        guard var components = URLComponents(string: "\(host)\(path)") else {
            return nil
        }

         // Add query items
        components.queryItems = queryItems

         return components.url
    }
    
    // MARK: Initialization
    
    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            // Failed to parse URL components
            return nil
        }
        
        guard let pathComponents = UniversalLinkPathComponents(path: components.path) else {
            // Unexpected value for path
            return nil
        }
        
        self.pathComponents = pathComponents
        self.queryItems = components.queryItems
    }
    
    init(path: UniversalLinkPath, parameters: UniversalLinkParameters) {
        self.pathComponents = UniversalLinkPathComponents(path: path)
        self.queryItems = parameters.queryItems
    }
    
}
