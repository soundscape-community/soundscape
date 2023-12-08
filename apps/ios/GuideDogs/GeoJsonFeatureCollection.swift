//
//  GeoJsonFeatureCollection.swift
//  Soundscape
//
//  Created by Kai on 11/10/23.
//  Copyright © 2023 Soundscape community. All rights reserved.
//

import Foundation

final class FailableDecode<T: Decodable>: Decodable {
    var result: Result<T, Error>
    
    public init(from decoder: Decoder) throws {
        result = Result(catching: { try T(from: decoder) })
    }
}

/// Represents the parsed json response from the OSM tiles service
final class GeoJsonFeatureCollection: Decodable {
    var features: [GeoJsonFeature]
    
    private enum CodingKeys: CodingKey {
        /// Contains an array of ``GeoJsonFeature``s
        case features
        /// Should always be `"FeatureCollection"`
        case type
    }
    
    enum GeoJsonFeatureCollectionParseError: Error {
        /// The `type` property of an ``GeoJsonFeatureCollection`` should always be `"FeatureCollection"`
        case incorrectTypeField
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        guard type == "FeatureCollection" else {
            throw GeoJsonFeatureCollectionParseError.incorrectTypeField
        }
        
        /// Some parsed features may error, since our ``GeoJsonFeature`` implementation requires a name
        /// As a result, we simply filter out the failing ones
        let parsed_features = try container.decode([FailableDecode<GeoJsonFeature>].self, forKey: .features)
        features = parsed_features.compactMap({
            switch $0.result {
                case .success(let feature): return feature
                case .failure(_): return nil
            }
        })
        
    }
}
