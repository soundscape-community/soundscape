//
//  OSMServiceModel.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

enum HTTPStatusCode: Equatable {
    typealias RawValue = Int
    case unknown(_ code: RawValue)
    case success
    case notModified
    
    public init(rawValue: RawValue) {
        switch rawValue {
        case 200:
            self = .success
        case 304:
            self = .notModified
        default:
            self = .unknown(rawValue)
        }
    }
    
    var rawValue: RawValue {
        switch self {
        case .unknown(let code):
            return code
        case .success:
            return 200
        case .notModified:
            return 304
        }
    }
}

enum HTTPHeader: String {
    case ifNoneMatch = "If-None-Match"
    case eTag = "Etag"
}

enum OSMServiceError: Error {
    /// Means that we were unable to convert the response into an `HTTPURLResponse`
    case badServerResponse
    /// If the response had a bad status code
    case badStatusCode(code: Int)
    case jsonParseFailed
    /// Occurs when `getDynamicData` receives an invalid URL
    case invalidDynamicURL
    /// Occurs when `getDynamicData` fails to decode the received string with utf-8
    case stringDecodingFailed
}

class OSMServiceModel: OSMServiceModelProtocol {
    /// Path to the tile server
    private static let path = "/tiles"
    public static let shared = OSMServiceModel()
    
    /// Asynchronously gets
    func getTileData(tile: VectorTile, categories: SuperCategories) async throws -> OSMServiceResult {
        let url = URL(string: "\(ServiceModel.servicesHostName)\(OSMServiceModel.path)/\(tile.zoom)/\(tile.x)/\(tile.y).json")!
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: ServiceModel.requestTimeout)
        
        // Set the etag header if it is cached
        try autoreleasepool {
            let cache = try RealmHelper.getCacheRealm()
            
            var etag = ""
            if let tiledata = cache.object(ofType: TileData.self, forPrimaryKey: tile.quadKey) {
                etag = tiledata.etag
            }
            request.setValue(etag, forHTTPHeaderField: HTTPHeader.ifNoneMatch.rawValue)
        }
        
        // Set `App-Version` header
        request.setAppVersionHeader()
        
        // Some housekeeping: Show the network activity indicator on the status bar, and log the request
        ServiceModel.logNetworkRequest(request)
        let (data, response) = try await URLSession.shared.data(for: request)
        // TODO: log these errors
        //ServiceModel.logNetworkResponse(response, request: request, error: error)
        
        
        // Is the response of the proper type? (it always should be...)
        guard let httpResponse = response as? HTTPURLResponse else {
            GDLogNetworkError("Response error: response object is not an HTTPURLResponse")
            throw OSMServiceError.badServerResponse
        }
        
        let newEtag = httpResponse.value(forHTTPHeaderField: HTTPHeader.eTag.rawValue) ?? NSUUID().uuidString

        
        switch HTTPStatusCode(rawValue: httpResponse.statusCode) {
        case .unknown(let code):
            throw OSMServiceError.badStatusCode(code: code)
        case .notModified:
            // Check the ETag (if the request returned a 304, then there is nothing to do because the data hasn't changed)
            // TODO: in what case will this happen? how does this work?
            return .notModified
        case .success:
            let featureCollection = try JSONDecoder().decode(GeoJsonFeatureCollection.self, from: data)
            
            return .modified(newEtag: newEtag, tileData: TileData(withParsedData: featureCollection, quadkey: tile.quadKey, etag: newEtag, superCategories: categories))
        }
    }
    
    func getDynamicData(dynamicURL: String) async throws -> String {
        guard !dynamicURL.isEmpty, let url = URL(string: dynamicURL) else {
            throw OSMServiceError.invalidDynamicURL
        }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: ServiceModel.requestTimeout)
        request.setValue("plain/text", forHTTPHeaderField: "Accept")
        request.setValue("Soundscape/0.1 (https://github.com/openscape-community/openscape)", forHTTPHeaderField: "User-Agent")

        // Some housekeeping: Show the network activity indicator on the status bar, and log the request
        ServiceModel.logNetworkRequest(request)
        
        // Create the data task and start it
        let (data, response) = try await URLSession.shared.data(for: request)
        // TODO: log if this errors
        //ServiceModel.logNetworkResponse(response, request: request, error: error)
        // Is the response of the proper type? (it always should be...)
        guard let httpResponse = response as? HTTPURLResponse else {
            GDLogNetworkError("Response error: response object is not an HTTPURLResponse")
            throw OSMServiceError.badServerResponse
        }
        
        if case .unknown(let code) = HTTPStatusCode(rawValue: httpResponse.statusCode) {
            // Make sure we have a known status
            throw OSMServiceError.badStatusCode(code: code)
        }
        
        guard let decodedString = String(data: data, encoding: .utf8) else {
            throw OSMServiceError.stringDecodingFailed
        }
        return decodedString
    }
}
