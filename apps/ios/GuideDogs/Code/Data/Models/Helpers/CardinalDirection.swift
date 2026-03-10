//
//  CardinalDirection.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import CoreLocation
import SSLanguage

typealias CardinalDirection = SSLanguage.CardinalDirection

extension SSLanguage.CardinalDirection {
    init?(direction: CLLocationDirection) {
        self.init(direction: Double(direction))
    }

    var localizedString: String {
        localizedString(locale: LocalizationContext.currentAppLocale)
    }

    var localizedAbbreviatedString: String {
        localizedAbbreviatedString(locale: LocalizationContext.currentAppLocale)
    }
}
