import Foundation

public struct SSGeoCoordinate: Sendable, Hashable, Codable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public var isValid: Bool {
        latitude.isFinite &&
            longitude.isFinite &&
            (-90.0 ... 90.0).contains(latitude) &&
            (-180.0 ... 180.0).contains(longitude)
    }
}
