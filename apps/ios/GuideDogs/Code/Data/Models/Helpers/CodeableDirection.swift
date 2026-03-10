//
//  CodeableDirection.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import SSLanguage

typealias CodeableDirection = SSLanguage.CodeableDirection

extension SSLanguage.CodeableDirection {
    init(
        originCoordinate: CLLocationCoordinate2D? = nil,
        originHeading: CLLocationDirection? = nil,
        destinationCoordinate: CLLocationCoordinate2D,
        directionType: RelativeDirectionType = .combined
    ) {
        self.init(
            originCoordinate: originCoordinate?.ssGeoCoordinate,
            originHeading: originHeading,
            destinationCoordinate: destinationCoordinate.ssGeoCoordinate,
            directionType: directionType
        )
    }

    static func decode(
        string: String,
        originCoordinate: CLLocationCoordinate2D? = nil,
        originHeading: CLLocationDirection? = nil
    ) throws -> Result {
        try decode(
            string: string,
            originCoordinate: originCoordinate?.ssGeoCoordinate,
            originHeading: originHeading
        )
    }
}
