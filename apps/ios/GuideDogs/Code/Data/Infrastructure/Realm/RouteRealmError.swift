//
//  RouteRealmError.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation

enum RouteDataError: Error {
    case databaseError
    case doesNotExist
    case invalidReadContract
}
