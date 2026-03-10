//
//  Category.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import SSDataDomain

typealias SuperCategories = SSDataDomain.SuperCategories
typealias SuperCategory = SSDataDomain.SuperCategory

extension SSDataDomain.SuperCategory {
    var glyph: StaticAudioEngineAsset {
        switch self {
        case .information:
            return StaticAudioEngineAsset.infoAlert
        case .mobility:
            return StaticAudioEngineAsset.mobilitySense
        case .safety:
            return StaticAudioEngineAsset.safetySense
        case .authoredActivity:
            return StaticAudioEngineAsset.tourPoiSense
        case .navilens:
            return StaticAudioEngineAsset.navilensSense
        default:
            return StaticAudioEngineAsset.poiSense
        }
    }
}
