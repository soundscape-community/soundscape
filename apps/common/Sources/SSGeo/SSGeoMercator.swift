// Copyright (c) Soundscape Community Contributers.

import Foundation

public enum SSGeoMercator {
    public static let earthRadiusMeters = 6_378_137.0
    public static let minLatitude = -85.05112878
    public static let maxLatitude = 85.05112878
    public static let minLongitude = -180.0
    public static let maxLongitude = 180.0

    public static func clip(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        Swift.min(Swift.max(value, minimum), maximum)
    }

    public static func mapSize(zoom: UInt) -> UInt {
        let base: UInt = 256
        return base << zoom
    }

    public static func groundResolution(latitude: Double, zoom: UInt) -> Double {
        let clippedLatitude = clip(latitude, min: minLatitude, max: maxLatitude)
        return cos(clippedLatitude * .pi / 180.0) * 2.0 * .pi * earthRadiusMeters / Double(mapSize(zoom: zoom))
    }

    public static func pixelXY(for coordinate: SSGeoCoordinate, zoom zoomLevel: UInt) -> (x: Int, y: Int) {
        let latitude = clip(coordinate.latitude, min: minLatitude, max: maxLatitude)
        let longitude = clip(coordinate.longitude, min: minLongitude, max: maxLongitude)

        let sinLatitude = sin(latitude * .pi / 180.0)
        let x = (longitude + 180.0) / 360.0
        let y = 0.5 - log((1.0 + sinLatitude) / (1.0 - sinLatitude)) / (.pi * 4.0)

        let size = Double(mapSize(zoom: zoomLevel))
        let pixelX = Int(clip(x * size + 0.5, min: 0.0, max: size - 1.0))
        let pixelY = Int(clip(y * size + 0.5, min: 0.0, max: size - 1.0))
        return (pixelX, pixelY)
    }

    public static func coordinate(forPixelX pixelX: Int, pixelY: Int, zoom zoomLevel: UInt) -> SSGeoCoordinate {
        let size = Double(mapSize(zoom: zoomLevel))
        let x = clip(Double(pixelX), min: 0.0, max: size - 1.0) / size - 0.5
        let y = 0.5 - clip(Double(pixelY), min: 0.0, max: size - 1.0) / size

        let latitude = 90.0 - 360.0 * atan(exp(-y * 2.0 * .pi)) / .pi
        let longitude = 360.0 * x
        return SSGeoCoordinate(latitude: latitude, longitude: longitude)
    }

    public static func tileXY(pixelX: Int, pixelY: Int) -> (x: Int, y: Int) {
        (pixelX / 256, pixelY / 256)
    }

    public static func pixelXY(tileX: Int, tileY: Int) -> (x: Int, y: Int) {
        (tileX * 256, tileY * 256)
    }

    public static func contains(
        _ coordinate: SSGeoCoordinate,
        in polygon: [SSGeoCoordinate],
        zoom: UInt = 16
    ) -> Bool {
        guard !polygon.isEmpty else {
            return false
        }

        if polygon.count == 1 {
            return polygon[0] == coordinate
        }

        if polygon.count == 2 {
            let result = projectedDistanceSquared(
                from: coordinate,
                toSegmentStart: polygon[0],
                end: polygon[1],
                zoom: zoom
            )
            return result.distanceSquaredPixels < 1.0
        }

        let point = pixelPoint(for: coordinate, zoom: zoom)
        let vertices = polygon.map { pixelPoint(for: $0, zoom: zoom) }

        var contains = false
        var previousIndex = vertices.count - 1

        for index in vertices.indices {
            let vertex = vertices[index]
            let previous = vertices[previousIndex]

            let intersects = ((vertex.y > point.y) != (previous.y > point.y)) &&
                (point.x < (previous.x - vertex.x) * (point.y - vertex.y) / (previous.y - vertex.y) + vertex.x)

            if intersects {
                contains.toggle()
            }

            previousIndex = index
        }

        return contains
    }

    public static func projectedDistanceSquared(
        from coordinate: SSGeoCoordinate,
        toSegmentStart start: SSGeoCoordinate,
        end: SSGeoCoordinate,
        zoom: UInt
    ) -> (distanceSquaredPixels: Double, closestCoordinate: SSGeoCoordinate) {
        let startPoint = pixelPoint(for: start, zoom: zoom)
        let endPoint = pixelPoint(for: end, zoom: zoom)
        let coordinatePoint = pixelPoint(for: coordinate, zoom: zoom)

        if startPoint.x == endPoint.x && startPoint.y == endPoint.y {
            let distanceSquared = squaredDistance(from: coordinatePoint, to: startPoint)
            return (distanceSquared, start)
        }

        let ab = (x: endPoint.x - startPoint.x, y: endPoint.y - startPoint.y)
        let ac = (x: coordinatePoint.x - startPoint.x, y: coordinatePoint.y - startPoint.y)
        let coefficient = dot(ab, ac) / dot(ab, ab)

        var projected = (
            x: startPoint.x + ab.x * coefficient,
            y: startPoint.y + ab.y * coefficient
        )

        if startPoint.x != endPoint.x {
            let left = startPoint.x < endPoint.x ? startPoint : endPoint
            let right = startPoint.x > endPoint.x ? startPoint : endPoint

            if projected.x <= startPoint.x && projected.x <= endPoint.x {
                projected = left
            } else if projected.x >= startPoint.x && projected.x >= endPoint.x {
                projected = right
            }
        } else {
            let lower = startPoint.y < endPoint.y ? startPoint : endPoint
            let upper = startPoint.y > endPoint.y ? startPoint : endPoint

            if projected.y <= startPoint.y && projected.y <= endPoint.y {
                projected = lower
            } else if projected.y >= startPoint.y && projected.y >= endPoint.y {
                projected = upper
            }
        }

        let closestCoordinate = Self.coordinate(
            forPixelX: Int(projected.x),
            pixelY: Int(projected.y),
            zoom: zoom
        )
        let distanceSquared = squaredDistance(from: coordinatePoint, to: projected)
        return (distanceSquared, closestCoordinate)
    }

    public static func closestCoordinate(
        to coordinate: SSGeoCoordinate,
        on path: [SSGeoCoordinate],
        zoom: UInt = 23
    ) -> SSGeoCoordinate? {
        guard path.count > 1 else {
            return nil
        }

        var closestCoordinate: SSGeoCoordinate?
        var minimumDistanceSquared = Double.greatestFiniteMagnitude

        for index in 0 ..< path.count - 1 {
            let start = path[index]
            let end = path[index + 1]
            guard start != end else {
                continue
            }

            let result = projectedDistanceSquared(
                from: coordinate,
                toSegmentStart: start,
                end: end,
                zoom: zoom
            )

            if result.distanceSquaredPixels < minimumDistanceSquared {
                minimumDistanceSquared = result.distanceSquaredPixels
                closestCoordinate = result.closestCoordinate
            }
        }

        return closestCoordinate
    }

    private static func pixelPoint(for coordinate: SSGeoCoordinate, zoom: UInt) -> (x: Double, y: Double) {
        let pixel = pixelXY(for: coordinate, zoom: zoom)
        return (Double(pixel.x), Double(pixel.y))
    }

    private static func squaredDistance(
        from point: (x: Double, y: Double),
        to other: (x: Double, y: Double)
    ) -> Double {
        let dx = point.x - other.x
        let dy = point.y - other.y
        return dx * dx + dy * dy
    }

    private static func dot(_ lhs: (x: Double, y: Double), _ rhs: (x: Double, y: Double)) -> Double {
        lhs.x * rhs.x + lhs.y * rhs.y
    }
}
