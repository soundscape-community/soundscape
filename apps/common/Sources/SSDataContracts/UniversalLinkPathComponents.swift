// Copyright (c) Soundscape Community Contributers.

import Foundation

public struct UniversalLinkPathComponents: Sendable {
    public let path: UniversalLinkPath
    public let version: UniversalLinkVersion

    public var versionedPath: String {
        "/\(version.rawValue)/\(path.rawValue)"
    }

    public init?(path: String) {
        let pathComponents = path.split(separator: "/", maxSplits: 1)

        if pathComponents.count == 1 {
            let pathRawValue = String(pathComponents[0])
            guard let path = UniversalLinkPath(rawValue: pathRawValue) else {
                return nil
            }

            version = UniversalLinkVersion.defaultVersion
            self.path = path
        } else if pathComponents.count == 2 {
            let versionRawValue = String(pathComponents[0])
            let pathRawValue = String(pathComponents[1])

            guard let version = UniversalLinkVersion(rawValue: versionRawValue),
                  let path = UniversalLinkPath(rawValue: pathRawValue) else {
                return nil
            }

            self.version = version
            self.path = path
        } else {
            return nil
        }
    }

    public init(path: UniversalLinkPath) {
        self.path = path
        version = UniversalLinkVersion.currentVersion(for: path)
    }
}
