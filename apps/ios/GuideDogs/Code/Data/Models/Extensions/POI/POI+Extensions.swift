//
//  POI+Extensions.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation

extension POI {
    
    func isEqual(_ poi: POI) -> Bool {
        return self.key == poi.key
    }
}
