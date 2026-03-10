// Copyright (c) Soundscape Community Contributers.

import Foundation

public struct MarkerParameters: Codable, Sendable {
    public let id: String?
    public let nickname: String?
    public let annotation: String?
    public let estimatedAddress: String?
    public let lastUpdatedDate: Date?
    public let location: LocationParameters

    public init(
        id: String?,
        nickname: String?,
        annotation: String?,
        estimatedAddress: String?,
        lastUpdatedDate: Date?,
        location: LocationParameters
    ) {
        self.id = id
        self.nickname = nickname
        self.annotation = annotation
        self.estimatedAddress = estimatedAddress
        self.lastUpdatedDate = lastUpdatedDate
        self.location = location
    }

    public init(name: String, latitude: Double, longitude: Double) {
        let coordinate = CoordinateParameters(latitude: latitude, longitude: longitude)
        let location = LocationParameters(name: name, address: nil, coordinate: coordinate, entity: nil)

        self.init(id: nil,
                  nickname: nil,
                  annotation: nil,
                  estimatedAddress: nil,
                  lastUpdatedDate: nil,
                  location: location)
    }
}

extension MarkerParameters: UniversalLinkParameters {
    private struct Name {
        static let nickname = "nickname"
        static let annotation = "annotation"
    }

    public var queryItems: [URLQueryItem] {
        var queryItems: [URLQueryItem] = []

        if let nickname {
            queryItems.append(URLQueryItem(name: Name.nickname, value: nickname))
        }

        if let annotation {
            queryItems.append(URLQueryItem(name: Name.annotation, value: annotation))
        }

        queryItems.append(contentsOf: location.queryItems)
        return queryItems
    }

    public init?(queryItems: [URLQueryItem]) {
        guard let location = LocationParameters(queryItems: queryItems) else {
            return nil
        }

        self.init(id: nil,
                  nickname: queryItems.first(where: { $0.name == Name.nickname })?.value,
                  annotation: queryItems.first(where: { $0.name == Name.annotation })?.value,
                  estimatedAddress: nil,
                  lastUpdatedDate: nil,
                  location: location)
    }
}
