// Copyright (c) Soundscape Community Contributers.

import Foundation

public struct RouteWaypoint: Sendable {
    public var index: Int = -1
    public var markerId: String = ""
    public var importedReferenceEntity: ReferenceEntity?

    public init() {}

    public init(index: Int, markerId: String, importedReferenceEntity: ReferenceEntity?) {
        self.index = index
        self.markerId = markerId
        self.importedReferenceEntity = importedReferenceEntity
    }
}

public extension Array where Element == RouteWaypoint {
    var ordered: [RouteWaypoint] {
        sorted(by: { $0.index < $1.index })
    }
}
