//
//  Direction.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import CoreLocation
import SSLanguage

typealias RelativeDirectionType = SSLanguage.RelativeDirectionType
typealias Direction = SSLanguage.Direction

extension SSLanguage.Direction {
    init(from direction: CLLocationDirection, to otherDirection: CLLocationDirection, type: RelativeDirectionType = .individual) {
        self.init(from: Double(direction), to: Double(otherDirection), type: type)
    }

    init(from direction: CLLocationDirection, type: RelativeDirectionType = .individual) {
        self.init(from: Double(direction), type: type)
    }

    var localizedString: String {
        localizedString(locale: LocalizationContext.currentAppLocale)
    }
}
