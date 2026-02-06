import Foundation

public enum SSGeoMath {
    // Spherical earth radius used by haversine distance.
    public static let earthRadiusMeters = 6_371_000.0

    public static func distanceMeters(
        from: SSGeoCoordinate,
        to: SSGeoCoordinate,
        earthRadiusMeters: Double = earthRadiusMeters
    ) -> Double {
        let lat1 = from.latitude * .pi / 180.0
        let lon1 = from.longitude * .pi / 180.0
        let lat2 = to.latitude * .pi / 180.0
        let lon2 = to.longitude * .pi / 180.0

        let dLat = lat2 - lat1
        let dLon = lon2 - lon1

        let a = sin(dLat / 2.0) * sin(dLat / 2.0) +
            cos(lat1) * cos(lat2) *
            sin(dLon / 2.0) * sin(dLon / 2.0)
        let c = 2.0 * atan2(sqrt(a), sqrt(1.0 - a))

        return earthRadiusMeters * c
    }

    public static func initialBearingDegrees(from: SSGeoCoordinate, to: SSGeoCoordinate) -> Double {
        let lat1 = from.latitude * .pi / 180.0
        let lon1 = from.longitude * .pi / 180.0
        let lat2 = to.latitude * .pi / 180.0
        let lon2 = to.longitude * .pi / 180.0
        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearingDegrees = atan2(y, x) * 180.0 / .pi

        return normalizedDegrees(bearingDegrees)
    }

    public static func speedMetersPerSecond(from: SSGeoLocation, to: SSGeoLocation) -> Double? {
        guard let start = from.timestamp, let end = to.timestamp else {
            return nil
        }

        let durationSeconds = end.timeIntervalSince(start)
        guard durationSeconds > 0 else {
            return nil
        }

        let distance = distanceMeters(from: from.coordinate, to: to.coordinate)
        return distance / durationSeconds
    }

    public static func normalizedDegrees(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360.0)
        return value < 0 ? value + 360.0 : value
    }
}
