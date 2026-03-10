// Copyright (c) Soundscape Community Contributers.

import Foundation

public struct EntityParameters: Codable, Sendable {
    public enum Source: Int, Codable, Sendable {
        case osm
    }

    public let source: Source
    public let lookupInformation: String

    public init(source: Source, lookupInformation: String) {
        self.source = source
        self.lookupInformation = lookupInformation
    }
}

extension EntityParameters: UniversalLinkParameters {
    private struct Name {
        static let source = "source"

        static func lookupInformation(for source: Source) -> String {
            switch source {
            case .osm:
                return "id"
            }
        }
    }

    public var queryItems: [URLQueryItem] {
        let name = Name.lookupInformation(for: source)
        return [
            URLQueryItem(name: Name.source, value: "\(source.rawValue)"),
            URLQueryItem(name: name, value: lookupInformation),
        ]
    }

    public init?(queryItems: [URLQueryItem]) {
        guard let rawValueString = queryItems.first(where: { $0.name == Name.source })?.value,
              let rawValue = Int(rawValueString),
              let source = Source(rawValue: rawValue) else {
            return nil
        }

        let name = Name.lookupInformation(for: source)
        guard let lookupInformation = queryItems.first(where: { $0.name == name })?.value else {
            return nil
        }

        self.init(source: source, lookupInformation: lookupInformation)
    }
}
