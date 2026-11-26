//
//  Category.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SSData

typealias SuperCategory = SSData.SuperCategory
typealias SuperCategories = SSData.SuperCategories

extension SuperCategory {
    var glyph: StaticAudioEngineAsset {
        switch self {
        case .information: return StaticAudioEngineAsset.infoAlert
        case .mobility: return StaticAudioEngineAsset.mobilitySense
        case .safety: return StaticAudioEngineAsset.safetySense
        case .authoredActivity: return StaticAudioEngineAsset.tourPoiSense
        case .navilens: return StaticAudioEngineAsset.navilensSense
        default: return StaticAudioEngineAsset.poiSense
        }
    }
    
}
