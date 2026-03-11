// Copyright (c) Soundscape Community Contributers.

import Foundation

public enum SSGeoPath {
    public static let maxDistanceForBearingCalculation = 25.0

    public static func pathBearing(
        for path: [SSGeoCoordinate],
        maxDistance: Double = Double.greatestFiniteMagnitude
    ) -> Double? {
        guard let firstCoordinate = path.first else {
            return nil
        }

        guard let referenceCoordinate = referenceCoordinate(on: path, for: maxDistance) else {
            return nil
        }

        return firstCoordinate.initialBearing(to: referenceCoordinate)
    }

    public static func split(
        path: [SSGeoCoordinate],
        atCoordinate coordinate: SSGeoCoordinate,
        reversedDirection: Bool = false
    ) -> [SSGeoCoordinate] {
        guard let coordinateIndex = path.firstIndex(where: { coordinatesEqual($0, coordinate) }) else {
            return []
        }

        return reversedDirection ?
            Array(path[...coordinateIndex].reversed()) :
            Array(path[coordinateIndex...])
    }

    public static func rotate(
        circularPath path: [SSGeoCoordinate],
        atCoordinate coordinate: SSGeoCoordinate,
        reversedDirection: Bool = false
    ) -> [SSGeoCoordinate] {
        guard pathIsCircular(path),
              let coordinateIndex = path.firstIndex(where: { coordinatesEqual($0, coordinate) }) else {
            return []
        }

        guard coordinateIndex != 0 else {
            return reversedDirection ? path.reversed() : path
        }

        let back = Array(path[coordinateIndex ..< (path.count - 1)])
        let front = Array(path[0 ... coordinateIndex])
        return reversedDirection ? (back + front).reversed() : back + front
    }

    public static func pathIsCircular(_ path: [SSGeoCoordinate]) -> Bool {
        guard path.count > 2, let first = path.first, let last = path.last else {
            return false
        }

        return coordinatesEqual(first, last)
    }

    public static func pathDistance(_ path: [SSGeoCoordinate]) -> Double {
        guard path.count > 1 else {
            return 0
        }

        var distance = 0.0
        for index in 0 ..< path.count - 1 {
            distance += path[index].distance(to: path[index + 1])
        }

        return distance
    }

    public static func referenceCoordinate(
        on path: [SSGeoCoordinate],
        for targetDistance: Double
    ) -> SSGeoCoordinate? {
        guard !path.isEmpty else {
            return nil
        }

        if path.count == 1 || targetDistance <= 0 {
            return path.first
        }

        if !targetDistance.isFinite || targetDistance == Double.greatestFiniteMagnitude {
            return path.last
        }

        var totalDistance = 0.0

        for index in 0 ..< path.count - 1 {
            let coordinate = path[index]
            let nextCoordinate = path[index + 1]
            let coordinateDistance = coordinate.distance(to: nextCoordinate)
            totalDistance += coordinateDistance

            if totalDistance == targetDistance {
                return nextCoordinate
            }

            if totalDistance > targetDistance {
                let previousTotalDistance = totalDistance - coordinateDistance
                let distanceToTarget = targetDistance - previousTotalDistance
                return coordinate.coordinateBetween(
                    coordinate: nextCoordinate,
                    distanceMeters: distanceToTarget
                )
            }
        }

        return path.last
    }

    public static func interpolateToEqualDistance(
        coordinates: [SSGeoCoordinate],
        distance targetDistance: Double
    ) -> [SSGeoCoordinate] {
        guard coordinates.count > 1 else {
            return coordinates
        }

        var totalInterpolation: [SSGeoCoordinate] = []

        for index in 0 ..< coordinates.count - 1 {
            let coordinate = coordinates[index]
            let nextCoordinate = coordinates[index + 1]

            var interpolation = interpolateToEqualDistance(
                start: coordinate,
                end: nextCoordinate,
                distance: targetDistance
            )

            if index != coordinates.count - 2 {
                interpolation.removeLast()
            }

            totalInterpolation.append(contentsOf: interpolation)
        }

        return totalInterpolation
    }

    public static func interpolateToEqualDistance(
        start: SSGeoCoordinate,
        end: SSGeoCoordinate,
        distance targetDistance: Double
    ) -> [SSGeoCoordinate] {
        let totalDistance = start.distance(to: end)
        guard targetDistance > 0, totalDistance > targetDistance else {
            return [start, end]
        }

        var coordinates = [start]
        var remainingDistance = totalDistance

        repeat {
            guard let previousCoordinate = coordinates.last else {
                break
            }

            let currentCoordinate = previousCoordinate.coordinateBetween(
                coordinate: end,
                distanceMeters: targetDistance
            )
            coordinates.append(currentCoordinate)
            remainingDistance = currentCoordinate.distance(to: end)
        } while remainingDistance > targetDistance

        coordinates.append(end)
        return coordinates
    }

    public static func centroid(coordinates: [SSGeoCoordinate]) -> SSGeoCoordinate? {
        guard !coordinates.isEmpty else {
            return nil
        }

        guard coordinates.count > 1 else {
            return coordinates[0]
        }

        var minLatitude = 90.0
        var maxLatitude = -90.0
        var minLongitude = 180.0
        var maxLongitude = -180.0

        for coordinate in coordinates {
            minLatitude = min(minLatitude, coordinate.latitude)
            maxLatitude = max(maxLatitude, coordinate.latitude)
            minLongitude = min(minLongitude, coordinate.longitude)
            maxLongitude = max(maxLongitude, coordinate.longitude)
        }

        return SSGeoCoordinate(
            latitude: (maxLatitude + minLatitude) / 2.0,
            longitude: (maxLongitude + minLongitude) / 2.0
        )
    }

    private static func coordinatesEqual(_ lhs: SSGeoCoordinate, _ rhs: SSGeoCoordinate) -> Bool {
        abs(lhs.latitude - rhs.latitude) <= 0.0000009 &&
            abs(lhs.longitude - rhs.longitude) <= 0.0000009
    }
}
