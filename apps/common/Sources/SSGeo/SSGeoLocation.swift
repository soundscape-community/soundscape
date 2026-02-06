import Foundation

public struct SSGeoLocation: Sendable, Hashable, Codable {
    public let coordinate: SSGeoCoordinate
    public let altitudeMeters: Double?
    public let timestamp: Date?
    public let horizontalAccuracyMeters: Double?
    public let verticalAccuracyMeters: Double?
    public let speedMetersPerSecond: Double?
    public let courseDegrees: Double?

    public init(
        coordinate: SSGeoCoordinate,
        altitudeMeters: Double? = nil,
        timestamp: Date? = nil,
        horizontalAccuracyMeters: Double? = nil,
        verticalAccuracyMeters: Double? = nil,
        speedMetersPerSecond: Double? = nil,
        courseDegrees: Double? = nil
    ) {
        self.coordinate = coordinate
        self.altitudeMeters = altitudeMeters
        self.timestamp = timestamp
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.verticalAccuracyMeters = verticalAccuracyMeters
        self.speedMetersPerSecond = speedMetersPerSecond
        self.courseDegrees = courseDegrees
    }
}
