// Copyright (c) Soundscape Community Contributers.

import Foundation

public enum UniversalLinkVersion: String, Codable, Sendable {
    case v1
    case v2
    case v3

    public static func currentVersion(for path: UniversalLinkPath) -> UniversalLinkVersion {
        switch path {
        case .experience: return .v3
        case .shareMarker: return .v1
        }
    }

    public static let defaultVersion: UniversalLinkVersion = .v1
}
