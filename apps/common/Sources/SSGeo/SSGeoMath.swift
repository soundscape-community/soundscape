import Foundation

public enum SSGeoMath {
    // WGS84 ellipsoid constants.
    public static let wgs84SemimajorAxisMeters = 6_378_137.0
    public static let wgs84Flattening = 1.0 / 298.257_223_563
    public static let wgs84SemiminorAxisMeters = (1.0 - wgs84Flattening) * wgs84SemimajorAxisMeters

    // Fixed spherical approximation used when a faster model is explicitly desired.
    public static let sphericalApproxEarthRadiusMeters = 6_371_000.0

    public static func distanceMeters(from: SSGeoCoordinate, to: SSGeoCoordinate) -> Double {
        if let inverse = vincentyInverse(from: from, to: to) {
            return inverse.distanceMeters
        }

        return distanceMetersSphericalApprox(from: from, to: to)
    }

    public static func distanceMetersSphericalApprox(from: SSGeoCoordinate, to: SSGeoCoordinate) -> Double {
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

        return sphericalApproxEarthRadiusMeters * c
    }

    public static func initialBearingDegrees(from: SSGeoCoordinate, to: SSGeoCoordinate) -> Double {
        if let inverse = vincentyInverse(from: from, to: to) {
            return normalizedDegrees(inverse.initialBearingDegrees)
        }

        return initialBearingDegreesSphericalApprox(from: from, to: to)
    }

    public static func initialBearingDegreesSphericalApprox(from: SSGeoCoordinate, to: SSGeoCoordinate) -> Double {
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

    public static func destinationCoordinate(
        from origin: SSGeoCoordinate,
        distanceMeters: Double,
        initialBearingDegrees: Double
    ) -> SSGeoCoordinate {
        if let coordinate = vincentyDirect(
            from: origin,
            distanceMeters: distanceMeters,
            initialBearingDegrees: initialBearingDegrees
        ) {
            return coordinate
        }

        return destinationCoordinateSphericalApprox(
            from: origin,
            distanceMeters: distanceMeters,
            initialBearingDegrees: initialBearingDegrees
        )
    }

    public static func destinationCoordinateSphericalApprox(
        from origin: SSGeoCoordinate,
        distanceMeters: Double,
        initialBearingDegrees: Double
    ) -> SSGeoCoordinate {
        let delta = distanceMeters / sphericalApproxEarthRadiusMeters
        let theta = initialBearingDegrees * .pi / 180.0

        let phi1 = origin.latitude * .pi / 180.0
        let lambda1 = origin.longitude * .pi / 180.0

        let sinPhi2 = sin(phi1) * cos(delta) + cos(phi1) * sin(delta) * cos(theta)
        let phi2 = asin(sinPhi2)
        let y = sin(theta) * sin(delta) * cos(phi1)
        let x = cos(delta) - sin(phi1) * sinPhi2
        let lambda2 = lambda1 + atan2(y, x)

        return SSGeoCoordinate(
            latitude: phi2 * 180.0 / .pi,
            longitude: normalizedLongitudeDegrees(lambda2 * 180.0 / .pi)
        )
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

    private static func normalizedLongitudeDegrees(_ longitude: Double) -> Double {
        let value = longitude.truncatingRemainder(dividingBy: 360.0)
        if value > 180.0 {
            return value - 360.0
        }
        if value < -180.0 {
            return value + 360.0
        }
        return value
    }

    private struct InverseSolution {
        let distanceMeters: Double
        let initialBearingDegrees: Double
    }

    private static func vincentyInverse(from: SSGeoCoordinate, to: SSGeoCoordinate) -> InverseSolution? {
        let phi1 = from.latitude * .pi / 180.0
        let phi2 = to.latitude * .pi / 180.0
        let l = (to.longitude - from.longitude) * .pi / 180.0

        let tanU1 = (1.0 - wgs84Flattening) * tan(phi1)
        let tanU2 = (1.0 - wgs84Flattening) * tan(phi2)
        let u1 = atan(tanU1)
        let u2 = atan(tanU2)

        let sinU1 = sin(u1)
        let cosU1 = cos(u1)
        let sinU2 = sin(u2)
        let cosU2 = cos(u2)

        var lambda = l
        var lambdaPrevious = 0.0

        var sinSigma = 0.0
        var cosSigma = 0.0
        var sigma = 0.0
        var sinAlpha = 0.0
        var cosSqAlpha = 0.0
        var cos2SigmaM = 0.0

        for _ in 0..<200 {
            let sinLambda = sin(lambda)
            let cosLambda = cos(lambda)

            let term1 = cosU2 * sinLambda
            let term2 = cosU1 * sinU2 - sinU1 * cosU2 * cosLambda
            let sum = term1 * term1 + term2 * term2
            sinSigma = sqrt(sum)

            if sinSigma == 0.0 {
                return InverseSolution(distanceMeters: 0.0, initialBearingDegrees: 0.0)
            }

            cosSigma = sinU1 * sinU2 + cosU1 * cosU2 * cosLambda
            sigma = atan2(sinSigma, cosSigma)

            sinAlpha = cosU1 * cosU2 * sinLambda / sinSigma
            cosSqAlpha = 1.0 - sinAlpha * sinAlpha

            if cosSqAlpha != 0.0 {
                cos2SigmaM = cosSigma - 2.0 * sinU1 * sinU2 / cosSqAlpha
            } else {
                cos2SigmaM = 0.0
            }

            let c = wgs84Flattening / 16.0 * cosSqAlpha *
                (4.0 + wgs84Flattening * (4.0 - 3.0 * cosSqAlpha))

            lambdaPrevious = lambda
            lambda = l + (1.0 - c) * wgs84Flattening * sinAlpha * (
                sigma + c * sinSigma * (
                    cos2SigmaM + c * cosSigma * (-1.0 + 2.0 * cos2SigmaM * cos2SigmaM)
                )
            )

            if abs(lambda - lambdaPrevious) <= 1e-12 {
                let uSq = cosSqAlpha * (wgs84SemimajorAxisMeters * wgs84SemimajorAxisMeters - wgs84SemiminorAxisMeters * wgs84SemiminorAxisMeters) /
                    (wgs84SemiminorAxisMeters * wgs84SemiminorAxisMeters)
                let a = 1.0 + uSq / 16_384.0 *
                    (4_096.0 + uSq * (-768.0 + uSq * (320.0 - 175.0 * uSq)))
                let b = uSq / 1_024.0 *
                    (256.0 + uSq * (-128.0 + uSq * (74.0 - 47.0 * uSq)))
                let deltaSigma = b * sinSigma * (
                    cos2SigmaM + b / 4.0 * (
                        cosSigma * (-1.0 + 2.0 * cos2SigmaM * cos2SigmaM)
                            - b / 6.0 * cos2SigmaM *
                            (-3.0 + 4.0 * sinSigma * sinSigma) *
                            (-3.0 + 4.0 * cos2SigmaM * cos2SigmaM)
                    )
                )

                let distance = wgs84SemiminorAxisMeters * a * (sigma - deltaSigma)
                let initialBearing = atan2(
                    cosU2 * sin(lambda),
                    cosU1 * sinU2 - sinU1 * cosU2 * cos(lambda)
                ) * 180.0 / .pi

                return InverseSolution(
                    distanceMeters: distance,
                    initialBearingDegrees: initialBearing
                )
            }
        }

        return nil
    }

    private static func vincentyDirect(
        from origin: SSGeoCoordinate,
        distanceMeters: Double,
        initialBearingDegrees: Double
    ) -> SSGeoCoordinate? {
        guard distanceMeters.isFinite else {
            return nil
        }

        let alpha1 = initialBearingDegrees * .pi / 180.0
        let phi1 = origin.latitude * .pi / 180.0
        let lambda1 = origin.longitude * .pi / 180.0

        let tanU1 = (1.0 - wgs84Flattening) * tan(phi1)
        let u1 = atan(tanU1)
        let sinU1 = sin(u1)
        let cosU1 = cos(u1)

        let sinAlpha1 = sin(alpha1)
        let cosAlpha1 = cos(alpha1)
        let sigma1 = atan2(tanU1, cosAlpha1)
        let sinAlpha = cosU1 * sinAlpha1
        let cosSqAlpha = 1.0 - sinAlpha * sinAlpha

        let uSq = cosSqAlpha * (wgs84SemimajorAxisMeters * wgs84SemimajorAxisMeters - wgs84SemiminorAxisMeters * wgs84SemiminorAxisMeters) /
            (wgs84SemiminorAxisMeters * wgs84SemiminorAxisMeters)
        let a = 1.0 + uSq / 16_384.0 *
            (4_096.0 + uSq * (-768.0 + uSq * (320.0 - 175.0 * uSq)))
        let b = uSq / 1_024.0 *
            (256.0 + uSq * (-128.0 + uSq * (74.0 - 47.0 * uSq)))

        var sigma = distanceMeters / (wgs84SemiminorAxisMeters * a)
        var sigmaPrevious = 0.0

        for _ in 0..<200 {
            let twoSigmaM = 2.0 * sigma1 + sigma
            let sinSigma = sin(sigma)
            let cosSigma = cos(sigma)
            let cosTwoSigmaM = cos(twoSigmaM)
            let deltaSigma = b * sinSigma * (
                cosTwoSigmaM + b / 4.0 * (
                    cosSigma * (-1.0 + 2.0 * cosTwoSigmaM * cosTwoSigmaM)
                        - b / 6.0 * cosTwoSigmaM *
                        (-3.0 + 4.0 * sinSigma * sinSigma) *
                        (-3.0 + 4.0 * cosTwoSigmaM * cosTwoSigmaM)
                )
            )

            sigmaPrevious = sigma
            sigma = distanceMeters / (wgs84SemiminorAxisMeters * a) + deltaSigma

            if abs(sigma - sigmaPrevious) <= 1e-12 {
                let sinSigmaFinal = sin(sigma)
                let cosSigmaFinal = cos(sigma)
                let twoSigmaMFinal = 2.0 * sigma1 + sigma
                let cosTwoSigmaMFinal = cos(twoSigmaMFinal)

                let tmp = sinU1 * sinSigmaFinal - cosU1 * cosSigmaFinal * cosAlpha1
                let phi2 = atan2(
                    sinU1 * cosSigmaFinal + cosU1 * sinSigmaFinal * cosAlpha1,
                    (1.0 - wgs84Flattening) * sqrt(sinAlpha * sinAlpha + tmp * tmp)
                )
                let lambda = atan2(
                    sinSigmaFinal * sinAlpha1,
                    cosU1 * cosSigmaFinal - sinU1 * sinSigmaFinal * cosAlpha1
                )
                let c = wgs84Flattening / 16.0 * cosSqAlpha *
                    (4.0 + wgs84Flattening * (4.0 - 3.0 * cosSqAlpha))
                let l = lambda - (1.0 - c) * wgs84Flattening * sinAlpha * (
                    sigma + c * sinSigmaFinal * (
                        cosTwoSigmaMFinal + c * cosSigmaFinal *
                        (-1.0 + 2.0 * cosTwoSigmaMFinal * cosTwoSigmaMFinal)
                    )
                )
                let lambda2 = lambda1 + l

                return SSGeoCoordinate(
                    latitude: phi2 * 180.0 / .pi,
                    longitude: normalizedLongitudeDegrees(lambda2 * 180.0 / .pi)
                )
            }
        }

        return nil
    }
}
