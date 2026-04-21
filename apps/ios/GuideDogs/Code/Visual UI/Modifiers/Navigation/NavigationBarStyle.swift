//
//  NavigationBarStyle.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

enum NavigationBarStyle {
    case transparent(foregroundColor: Color)
    case darkBlue
}

extension NavigationBarStyle {
    
    var foregroundColor: Color {
        switch self {
        case .transparent(let foregroundColor): return foregroundColor
        case .darkBlue: return .white
        }
    }
}
