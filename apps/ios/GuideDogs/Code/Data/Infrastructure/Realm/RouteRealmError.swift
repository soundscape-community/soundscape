//
//  RouteRealmError.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation

enum RouteRealmError: Error {
    case databaseError
    case doesNotExist
    case invalidReadContract
}
