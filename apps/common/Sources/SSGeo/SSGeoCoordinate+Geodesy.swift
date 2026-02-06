import Foundation

public extension SSGeoCoordinate {
    func distance(to coordinate: SSGeoCoordinate) -> Double {
        SSGeoMath.distanceMeters(from: self, to: coordinate)
    }

    func distanceSphericalApprox(to coordinate: SSGeoCoordinate) -> Double {
        SSGeoMath.distanceMetersSphericalApprox(from: self, to: coordinate)
    }

    func initialBearing(to coordinate: SSGeoCoordinate) -> Double {
        SSGeoMath.initialBearingDegrees(from: self, to: coordinate)
    }

    func initialBearingSphericalApprox(to coordinate: SSGeoCoordinate) -> Double {
        SSGeoMath.initialBearingDegreesSphericalApprox(from: self, to: coordinate)
    }

    func destination(distanceMeters: Double, initialBearingDegrees: Double) -> SSGeoCoordinate {
        SSGeoMath.destinationCoordinate(
            from: self,
            distanceMeters: distanceMeters,
            initialBearingDegrees: initialBearingDegrees
        )
    }

    func destinationSphericalApprox(distanceMeters: Double, initialBearingDegrees: Double) -> SSGeoCoordinate {
        SSGeoMath.destinationCoordinateSphericalApprox(
            from: self,
            distanceMeters: distanceMeters,
            initialBearingDegrees: initialBearingDegrees
        )
    }

    func coordinateBetween(coordinate: SSGeoCoordinate, distanceMeters: Double) -> SSGeoCoordinate {
        destination(distanceMeters: distanceMeters, initialBearingDegrees: initialBearing(to: coordinate))
    }
}
