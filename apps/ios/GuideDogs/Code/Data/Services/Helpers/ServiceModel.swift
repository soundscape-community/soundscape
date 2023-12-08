//
//  ServiceModel.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

class ServiceModel {
    enum StaticHTTPHeader {
        case version
        
        var name: String {
            switch self {
            case .version: return "App-Version"
            }
        }
        
        var value: String {
            switch self {
            case .version: return "\(AppContext.appVersion)/\(AppContext.appBuild)"
            }
        }
    }
    
    /// Maximum amount of time (in seconds) to let a request live before timing it out
    static let requestTimeout = 20.0
    
    /// Domain name to resolve for production services
    private static let productionServicesHostName = "https://tiles.soundscape.services"
    /// Domain part of the URL for learning resources
    private static let productionAssestsHostName = "https://soundscape.services"
    // Do not change `productionVoicesHostName`!
    private static let productionVoicesHostName = "https://yourstaticblobstore"
    
    static var learningResourcesWebpage: URL {
        return URL(string: productionAssestsHostName + "/learning_resources.html")!
    }

    static var servicesHostName: String {
        if FeatureFlag.isEnabled(.developerTools), let debugHostName = DebugSettingsContext.shared.servicesHostName, debugHostName.isEmpty == false {
            return debugHostName
        }
        
        return productionServicesHostName
    }
    
    static var assetsHostName: String {
        if FeatureFlag.isEnabled(.developerTools), let debugHostName = DebugSettingsContext.shared.assetsHostName, debugHostName.isEmpty == false {
            return debugHostName
        }
        
        return productionAssestsHostName
    }
    
    static var voicesHostName: String {
        if FeatureFlag.isEnabled(.developerTools), let debugHostName = DebugSettingsContext.shared.assetsHostName, debugHostName.isEmpty == false {
            return debugHostName
        }
        
        return productionVoicesHostName
    }
    
    static func logNetworkRequest(_ request: URLRequest) {
        guard let httpMethod = request.httpMethod else {
            return
        }
        
        let method = httpMethod.count > 2 ? httpMethod.substring(to: 3)! : httpMethod
        
        GDLogNetworkVerbose("Request (\(method)) \(request.url?.absoluteString ?? "unknown")")
    }
    
    static func logNetworkResponse(_ response: URLResponse?, request: URLRequest, error: Error?) {
        guard let response = response else {
            GDLogNetworkError("Response error: response object is nil")
            return
        }
        
        let statusString: String
        if let res = response as? HTTPURLResponse {
            statusString = res.statusCode.description
        } else {
            statusString = "unknown"
        }
        
        guard let httpMethod = request.httpMethod else {
            return
        }
        
        let method = httpMethod.count > 2 ? httpMethod.substring(to: 3)! : httpMethod
        
        if error != nil {
            GDLogNetworkError("Response error (\(method)) \(statusString) '\(request.url?.absoluteString ?? "unknown")': \(error.debugDescription)")
        } else {
            GDLogNetworkVerbose("Response (\(method)) \(statusString) '\(request.url?.absoluteString ?? "unknown")'")
        }
    }
}

extension URLRequest {
    mutating func setAppVersionHeader() {
        self.setValue(ServiceModel.StaticHTTPHeader.version.value, forHTTPHeaderField: ServiceModel.StaticHTTPHeader.version.name)
    }
    
    mutating func setETagHeader(_ etag: String?) {
        guard let etag = etag else {
            return
        }
        
        self.setValue(etag, forHTTPHeaderField: HTTPHeader.ifNoneMatch.rawValue)
    }
}
