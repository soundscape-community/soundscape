//
//  ServiceModelProtocol.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

/// Always means a good response
enum OSMServiceResult {
    case notModified
    case modified(newEtag: String, tileData: TileData)
}

protocol OSMServiceModelProtocol {
    
    // MARK: Functions
    func getTileData(tile: VectorTile, categories: SuperCategories) async throws -> OSMServiceResult
    func getDynamicData(dynamicURL: String) async throws -> String
}
