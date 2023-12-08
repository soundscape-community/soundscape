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

extension OSMServiceModelProtocol {
    /// Retries until success or `tries` attempts have been made. If unsuccessful, the last error will be thrown.
    func getTileData(tile: VectorTile, categories: SuperCategories, tries: Int) async throws -> OSMServiceResult {
        for _ in 0..<tries - 1 {
            do {
                return try await self.getTileData(tile: tile, categories: categories)
            } catch {
                // if we fail, then try again for n-1 tries
                continue
            }
        }
        // on the last (n-th) try, we don't catch
        return try await self.getTileData(tile: tile, categories: categories)
    }
}
