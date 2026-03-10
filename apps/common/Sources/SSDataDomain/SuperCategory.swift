// Copyright (c) Soundscape Community Contributers.

import Foundation

public typealias SuperCategories = [SuperCategory: Set<String>]

public enum SuperCategory: String, Sendable {
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

    public static func parseCategories(from data: Data) -> (version: Int, categories: SuperCategories)? {
        do {
            guard let categoryJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let version = categoryJSON["version"] as? Int,
                  let categories = categoryJSON["categories"] as? [String: [String]] else {
                return nil
            }

            var mapped: SuperCategories = [:]
            for (key, values) in categories {
                guard let category = SuperCategory(rawValue: key) else {
                    continue
                }

                mapped[category] = Set(values)
            }

            return (version: version, categories: mapped)
        } catch {
            return nil
        }
    }
}
