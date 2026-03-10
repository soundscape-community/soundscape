// Copyright (c) Soundscape Community Contributers.

import Foundation

public protocol UniversalLinkParameters {
    init?(queryItems: [URLQueryItem])
    var queryItems: [URLQueryItem] { get }
}

public extension UniversalLinkParameters {
    var percentEncodedQueryItems: [URLQueryItem] {
        var percentEncodedQueryItems: [URLQueryItem] = []

        let allowedChars = CharacterSet.alphanumerics

        for item in queryItems {
            let encodedValue = item.value?.addingPercentEncoding(withAllowedCharacters: allowedChars)
            percentEncodedQueryItems.append(URLQueryItem(name: item.name, value: encodedValue))
        }

        return percentEncodedQueryItems
    }
}
