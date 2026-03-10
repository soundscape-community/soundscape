// Copyright (c) Soundscape Community Contributers.

import Foundation

public struct CoordinateParameters: Codable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

extension CoordinateParameters: UniversalLinkParameters {
    private struct Name {
        static let latitude = "lat"
        static let longitude = "lon"
    }

    public var queryItems: [URLQueryItem] {
        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: Name.latitude, value: "\(latitude)"))
        queryItems.append(URLQueryItem(name: Name.longitude, value: "\(longitude)"))
        return queryItems
    }

    public init?(queryItems: [URLQueryItem]) {
        guard let latitudeStr = queryItems.first(where: { $0.name == Name.latitude })?.value,
              let latitude = Double(latitudeStr),
              let longitudeStr = queryItems.first(where: { $0.name == Name.longitude })?.value,
              let longitude = Double(longitudeStr) else {
            return nil
        }

        self.init(latitude: latitude, longitude: longitude)
    }
}
