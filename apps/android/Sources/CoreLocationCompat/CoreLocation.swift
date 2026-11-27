// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

public typealias CLLocationDegrees = Double
public typealias CLLocationDistance = Double

public struct CLLocationCoordinate2D: Sendable {
    public var latitude: CLLocationDegrees
    public var longitude: CLLocationDegrees

    public init(latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public final class CLLocation: Sendable {
    public let coordinate: CLLocationCoordinate2D

    public init(latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
