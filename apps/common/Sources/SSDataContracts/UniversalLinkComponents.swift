// Copyright (c) Soundscape Community Contributers.

import Foundation

public struct UniversalLinkComponents: Sendable {
    private static let host = "https://share.soundscape.services"

    public let pathComponents: UniversalLinkPathComponents
    public let queryItems: [URLQueryItem]?

    public var url: URL? {
        guard var components = URLComponents(string: "\(Self.host)\(pathComponents.versionedPath)") else {
            return nil
        }

        components.queryItems = queryItems
        return components.url
    }

    public init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let pathComponents = UniversalLinkPathComponents(path: components.path) else {
            return nil
        }

        self.pathComponents = pathComponents
        queryItems = components.queryItems
    }

    public init(path: UniversalLinkPath, parameters: any UniversalLinkParameters) {
        pathComponents = UniversalLinkPathComponents(path: path)
        queryItems = parameters.queryItems
    }
}
