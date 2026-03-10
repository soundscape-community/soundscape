// Copyright (c) Soundscape Community Contributers.

import Foundation

public struct LocationParameters: Codable, Sendable {
    public let name: String
    public let address: String?
    public let coordinate: CoordinateParameters
    public let entity: EntityParameters?

    public init(name: String, address: String?, coordinate: CoordinateParameters, entity: EntityParameters?) {
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.entity = entity
    }
}

extension LocationParameters: UniversalLinkParameters {
    private struct Name {
        static let name = "name"
    }

    public var queryItems: [URLQueryItem] {
        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: Name.name, value: name))
        queryItems.append(contentsOf: coordinate.queryItems)

        if let entity {
            queryItems.append(contentsOf: entity.queryItems)
        }

        return queryItems
    }

    public init?(queryItems: [URLQueryItem]) {
        guard let coordinate = CoordinateParameters(queryItems: queryItems),
              let name = queryItems.first(where: { $0.name == Name.name })?.value else {
            return nil
        }

        self.init(name: name,
                  address: nil,
                  coordinate: coordinate,
                  entity: EntityParameters(queryItems: queryItems))
    }
}
