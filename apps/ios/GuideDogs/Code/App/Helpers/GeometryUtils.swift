//
//  GeometryUtils.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation
import SSDataContracts
import SSGeo

/// Should contain two objects: latitude and longitude
typealias GAPoint = [CLLocationDegrees]

/// Should contain one or more points
typealias GALine = [GAPoint]

/// Should contain one or more lines
typealias GAMultiLine = [GALine]

// Should contain one or more multi lines
typealias GAMultiLineCollection = [GAMultiLine]

class GeometryUtils {
    
    static let maxRoadDistanceForBearingCalculation: CLLocationDistance = SSGeoPath.maxDistanceForBearingCalculation

    static let earthRadius = SSGeoMercator.earthRadiusMeters
    
    /// Parses a GeoJSON string and returns the coordinates and type values.
    ///
    /// See:
    /// * https://geojson.org
    /// * RFC 7946
    nonisolated static func coordinates(geoJson: String) -> (type: GeometryType?, points: [Any]?) {
        guard !geoJson.isEmpty, let jsonObject = GDAJSONObject(string: geoJson) else {
                return (nil, nil)
        }
        
        let geometryType: GeometryType?
        if let typeString = jsonObject.string(atPath: "type") {
            geometryType = GeometryType(rawValue: typeString)
        } else {
            geometryType = nil
        }
        
        guard let geometry = jsonObject.array(atPath: "coordinates") else {
            return (geometryType, nil)
        }
        
        return (geometryType, geometry)
    }
    
    /// Returns whether a coordinate lies inside of the region contained within the coordinate path.
    /// The path is always considered closed, regardless of whether the last point equals the first or not.
    nonisolated static func geometryContainsLocation(location: CLLocationCoordinate2D, coordinates: [CLLocationCoordinate2D]) -> Bool {
        SSGeoMercator.contains(
            location.ssGeoCoordinate,
            in: coordinates.map(\.ssGeoCoordinate),
            zoom: 16
        )
    }
    
    /// Calculates the bearing of a coordinates path.
    ///
    /// Calculates the bearing from the first coordinate on a path (i.e. an array of coordinates) to the furthest
    /// point on that path which is no further away from the first point than the specified `maxDistance`.
    ///
    /// - Parameters:
    ///     - for: The reference path.
    ///     - maxDistance: The max distance for calculating the reference coordinate along the path.
    /// - Returns: The bearing of a coordinates path.
    ///
    /// - note: The path most have more than one coordinate.
    ///
    /// Illustration:
    /// ```
    /// // A * *          - (A) first coordinate
    /// //     * * *
    /// //       ↘︎ *      - (↘︎) bearing from A to B
    /// //         B      - (B) max distance coordinate
    /// //         * * C  - (C) last coordinate
    /// ```
    nonisolated static func pathBearing(for path: [CLLocationCoordinate2D], maxDistance: CLLocationDistance = CLLocationDistanceMax) -> CLLocationDirection? {
        SSGeoPath.pathBearing(for: path.map(\.ssGeoCoordinate), maxDistance: maxDistance)
    }
    
    ///  Returns the sub-coordinates from a coordinate on a path until the end or start of the path.
    ///
    /// - Parameters:
    ///     - path: The reference path.
    ///     - coordinate: The reference coordinate.
    ///     - reversedDirection: If `true` is passed, the returned sub-coordinates will be
    ///     calculated from the reference coordinate to the start of the path.
    /// - Returns: The sub-coordinates from a coordinate on a path until the end or start of the path.
    nonisolated static func split(path: [CLLocationCoordinate2D],
                      atCoordinate coordinate: CLLocationCoordinate2D,
                      reversedDirection: Bool = false) -> [CLLocationCoordinate2D] {
        SSGeoPath.split(
            path: path.map(\.ssGeoCoordinate),
            atCoordinate: coordinate.ssGeoCoordinate,
            reversedDirection: reversedDirection
        ).map(\.clCoordinate)
    }
    
    /// Rotates the order of the coordinates in a circular path so that the specified coordinate is the first/last coordinate
    ///
    /// If the input path is [1, 2, 3, 4, 5, 1] and the coordinate to rotate about is 3, then the resulting path will be
    /// [3, 4, 5, 1, 2, 3] (or [3, 2, 1, 5, 4, 3] if the direction is reversed).
    ///
    /// - Parameters:
    ///   - path: The circular path to rotate. If a non-circular path is provided, an empty array will be returned
    ///   - coordinate: The reference coordinate
    ///   - reversedDirection: If `true` is passed, the returned coordinates will be reversed
    /// - Returns: A rotated version of the circular path passed in
    nonisolated static func rotate(circularPath path: [CLLocationCoordinate2D],
                       atCoordinate coordinate: CLLocationCoordinate2D,
                       reversedDirection: Bool = false) -> [CLLocationCoordinate2D] {
        SSGeoPath.rotate(
            circularPath: path.map(\.ssGeoCoordinate),
            atCoordinate: coordinate.ssGeoCoordinate,
            reversedDirection: reversedDirection
        ).map(\.clCoordinate)
    }
    
    ///  Returns `true` if the path is a circular path (the first coordinate is equal to the last coordinate,
    ///  and there are more than 2 coordinates).
    ///
    /// - Parameters:
    ///     - path: The reference path.
    /// - Returns: `true` if the path is a circular path, `false` otherwise.
    nonisolated static func pathIsCircular(_ path: [CLLocationCoordinate2D]) -> Bool {
        SSGeoPath.pathIsCircular(path.map(\.ssGeoCoordinate))
    }
    
    ///  Returns the distance of a coordinate path
    ///
    /// - Parameters:
    ///     - path: The reference path.
    /// - Returns: The distance of a coordinate path
    nonisolated static func pathDistance(_ path: [CLLocationCoordinate2D]) -> CLLocationDistance {
        SSGeoPath.pathDistance(path.map(\.ssGeoCoordinate))
    }
    
    /// Calculates a coordinate on a path at a target distance along the path from the path's first coordinate.
    /// - note: If the target distance is greater than the path distance, the last path coordinate is returned.
    /// - note: If the target distance is between two coordinates on the path, a synthesized coordinate between the coordinates is returned.
    /// - note: If the target distance is smaller or equal to zero, the first path coordinate is returned.
    nonisolated static func referenceCoordinate(on path: [CLLocationCoordinate2D], for targetDistance: CLLocationDistance) -> CLLocationCoordinate2D? {
        SSGeoPath.referenceCoordinate(
            on: path.map(\.ssGeoCoordinate),
            for: targetDistance
        )?.clCoordinate
    }
    
    nonisolated static func squaredDistance(location: CLLocationCoordinate2D,
                                start: CLLocationCoordinate2D,
                                end: CLLocationCoordinate2D,
                                zoom: UInt) -> (CLLocationDistance, CLLocationDegrees, CLLocationDegrees) {
        let result = SSGeoMercator.projectedDistanceSquared(
            from: location.ssGeoCoordinate,
            toSegmentStart: start.ssGeoCoordinate,
            end: end.ssGeoCoordinate,
            zoom: zoom
        )
        return (
            result.distanceSquaredPixels,
            result.closestCoordinate.latitude,
            result.closestCoordinate.longitude
        )
    }
    
    /// Finds the closest point on an edge of the polygon (including intermediate points along edges) to the given coordinate.
    /// - Returns: `nil` if the polygon is empty (i.e. no edges)
    nonisolated static func closestEdge(from coordinate: CLLocationCoordinate2D, on polygon: GAMultiLine) -> CLLocation? {
        var coordinates: [CLLocationCoordinate2D] = []
        
        // Transform to a continuous coordinates path
        for line in polygon {
            for point in line {
                coordinates.append(point.toCoordinate())
            }
        }
                
        return closestEdge(from: coordinate, on: coordinates)
    }
    
    /// Finds the closest point on the path (including intermediate points along edges) to the given coordinate.
    /// - Returns: `nil` if there are no edges (less than two points in `path`)
    nonisolated static func closestEdge(from coordinate: CLLocationCoordinate2D, on path: [CLLocationCoordinate2D]) -> CLLocation? {
        SSGeoMercator.closestCoordinate(
            to: coordinate.ssGeoCoordinate,
            on: path.map(\.ssGeoCoordinate),
            zoom: 23
        )?.clLocation
    }
    
    ///  Returns the interpolated path between coordinates in a coordinates array. The interpolated path
    ///  (coordinates between the original coordinates) will have a fixed distance of `distance`.
    ///
    /// Illustration:
    /// ```
    /// Original path:
    /// *-------------------*------*-*--------*
    /// Interpolated path:
    /// *----*----*----*----*----*-*-*----*---*
    /// ```
    ///
    /// - Parameters:
    ///     - coordinates: The original coordinate path.
    ///     - distance: The fixed distance to use between the interpolated coodinates.
    /// - Returns: A coordinate path including the original coordinates and any coordiantes between
    /// them with a fixed distance of `distance`.
    nonisolated static func interpolateToEqualDistance(coordinates: [CLLocationCoordinate2D],
                                           distance targetDistance: CLLocationDistance) -> [CLLocationCoordinate2D] {
        SSGeoPath.interpolateToEqualDistance(
            coordinates: coordinates.map(\.ssGeoCoordinate),
            distance: targetDistance
        ).map(\.clCoordinate)
    }
    
    ///  Returns the interpolated path between two coordinates. The interpolated path
    ///  (coordinates between `start` and `end`) will have a fixed distance of `distance`.
    ///
    /// Illustration:
    /// ```
    /// start             end
    /// *-------------------*
    /// *----*----*----*----*
    /// ```
    ///
    /// - Parameters:
    ///     - start: The start coordinate.
    ///     - end: The end coordinate.
    ///     - distance: The fixed distance to use between the interpolated coodinates.
    /// - Returns: An coordinates path including `start`, `end` and any coordiantes between
    /// them with a fixed distance of `distance`.
    nonisolated static func interpolateToEqualDistance(start: CLLocationCoordinate2D,
                                           end: CLLocationCoordinate2D,
                                           distance targetDistance: CLLocationDistance) -> [CLLocationCoordinate2D] {
        SSGeoPath.interpolateToEqualDistance(
            start: start.ssGeoCoordinate,
            end: end.ssGeoCoordinate,
            distance: targetDistance
        ).map(\.clCoordinate)
    }
    
}

// MARK: - Centroid Calculations

extension GeometryUtils {
    
    /// Returns a generated coordinate representing the mean center of a given array of coordinates.
    /// - Note: See `centroid(coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D?`
    nonisolated static func centroid(geoJson: String) -> CLLocationCoordinate2D? {
        guard let points = GeometryUtils.coordinates(geoJson: geoJson).points else {
            return nil
        }
        
        // Check if `points` contains one point (e.g. point)
        if let point = points as? GAPoint {
            return point.toCoordinate()
        }
        
        // Check if `points` contains an array of points (e.g. line, polygon)
        if let points = points as? GALine {
            return GeometryUtils.centroid(coordinates: points.toCoordinates())
        }
        
        // Check if `points` contains a two dimensional array of points (e.g. lines, polygons)
        if let points = points as? GAMultiLine {
            let flattened = Array(points.toCoordinates().joined())
            return GeometryUtils.centroid(coordinates: flattened)
        }
        
       return nil
    }
    
    /// Returns a generated coordinate representing the mean center of a given array of `CLLocation` objects.
    /// - Note: See `centroid(coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D?`
    nonisolated static func centroid(locations: [CLLocation]) -> CLLocationCoordinate2D? {
        return GeometryUtils.centroid(coordinates: locations.map { (location) -> CLLocationCoordinate2D in
            return location.coordinate
        })
    }
    
    /// Returns a generated coordinate representing the mean center of a given array of `CLLocationCoordinate2D` objects.
    ///
    /// The centroid calculation is done by creating a bound box for the coordinates and extracting the center,
    /// this means that any geometrical shape is acceptable.
    /// - Note: In practice, for extremely irregular shapes, this can lead to center coordinates not inside the shape.
    nonisolated static func centroid(coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D? {
        SSGeoPath.centroid(coordinates: coordinates.map(\.ssGeoCoordinate))?.clCoordinate
    }
    
}

// MARK: - Transforming Points to Coordinates

extension Array where Element == Double {
    /// Transform to a `CLLocationCoordinate2D` object.
    func toCoordinate() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2DMake(self[1], self[0])
    }
}

extension Array where Element == [Double] {
    /// Transform to an array of `CLLocationCoordinate2D` objects.
    func toCoordinates() -> [CLLocationCoordinate2D] {
        return self.map({ (point) -> CLLocationCoordinate2D in
            point.toCoordinate()
        })
    }
}

extension Array where Element == [[Double]] {
    /// Transform to multiple arrays of `CLLocationCoordinate2D` objects.
    func toCoordinates() -> [[CLLocationCoordinate2D]] {
        return self.map({ (points) -> [CLLocationCoordinate2D] in
            points.toCoordinates()
        })
    }
}

extension Array where Element == [[[Double]]] {
    /// Transform to multiple arrays of `CLLocationCoordinate2D` objects.
    func toCoordinates() -> [[[CLLocationCoordinate2D]]] {
        return self.map({ (points) -> [[CLLocationCoordinate2D]] in
            points.toCoordinates()
        })
    }
}
