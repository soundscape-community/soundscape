//
//  UniversalLinkPath.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

enum UniversalLinkPath: String {
    
    // `rawValue` should be the path (excluding version)
    // in the universal link URL
    //
    // e.g. "https://share.openscape.io/<Version>/<Path>?<QueryItems>"
    case experience = "experience"
    case shareMarker = "sharemarker"
    
}
