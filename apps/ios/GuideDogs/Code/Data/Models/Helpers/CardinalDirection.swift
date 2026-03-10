//
//  CardinalDirection.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import CoreLocation
import SSLanguage

extension CardinalDirection {
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
