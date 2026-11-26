//
//  SuperCategory.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation

public typealias SuperCategories = [SuperCategory: Set<String>]

public enum SuperCategory: String, Sendable {
    // MARK: Super Category Names
    case undefined = "undefined"
    case entrances = "entrance"
    case entranceLists = "entrances"
    case roads = "road"
    case paths = "path"
    case intersections = "intersection"
    case landmarks = "landmark"
    case places = "place"
    case mobility = "mobility"
    case information = "information"
    case objects = "object"
    case safety = "safety"
    case beacons = "beacons"
    case authoredActivity = "authoredActivity"
    case navilens = "navilens"

    // MARK: Static Methods

    public static func parseCategories(from: Data) -> (version: Int, categories: SuperCategories)? {
        do {
            guard let categoryJSON = try JSONSerialization.jsonObject(with: from) as? [String: Any] else {
                return nil
            }

            guard let version = categoryJSON["version"] as? Int else {
                return nil
            }

            guard let categories = categoryJSON["categories"] as? [String: [String]] else {
                return nil
            }

            var mapped: SuperCategories = [:]

            for (key, values) in categories {
                // Ignore unknown categories
                if let category = SuperCategory(rawValue: key) {
                    mapped[category] = Set(values)
                }
            }

            return (version: version, categories: mapped)
        } catch {
            return nil
        }
    }
}
