//
//  GeoJsonGeometry.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation

/// GeoJsonGeometry is a Swift representation of the `geometry` property in a GeoJSON feature.
/// Geometry types from the GeoJSON [spec](https://tools.ietf.org/html/rfc7946).
///
/// - `point`: The geometry consists of a single point
/// - `lineString`: The geometry consists of at least two points
/// - `multiPoint`: The geometry consists of any number of points
/// - `polygon`: The geometry consists of an array of linear ring coordinate arrays (see spec above)
/// - `multiLineString`: The geometry consists of an array of lineStrings
/// - `multiPolygon`: The geometry consists of an array of polygons
///
/// Note: every `coordinates` list and sub-list should have at least one point in it (or more depending on spec)
public enum GeoJsonGeometry: Equatable, Codable {
    /// The geometry consists of a single point
    case point(coordinates: CLLocationCoordinate2D)
    
    /// The geometry consists of at least two points
    case lineString(coordinates: [CLLocationCoordinate2D])
    
    /// The geometry consists of any number of points
    case multiPoint(coordinates: [CLLocationCoordinate2D])
    
    ///  The geometry consists of an array of linear ring coordinate arrays (see spec above)
    case polygon(coordinates: [[CLLocationCoordinate2D]])
    
    /// The geometry consists of an array of lineStrings
    case multiLineString(coordinates: [[CLLocationCoordinate2D]])
    
    /// The geometry consists of an array of polygons
    case multiPolygon(coordinates: [[[CLLocationCoordinate2D]]])
    
    public typealias RawValue = String
    
    public var rawValue: RawValue {
        switch self {
        case .point:
            return "Point"
        case .lineString:
            return "LineString"
        case .multiPoint:
            return "MultiPoint"
        case .polygon:
            return "Polygon"
        case .multiLineString:
            return "MultiLineString"
        case .multiPolygon:
            return "MultiPolygon"
        }
    }
    
    enum GeoJsonGeometryError: Error {
        /// When the `coordinates` property is of the correct type, but is semantically incorrect (e.g. being empty, or missing longitudes)
        case invalidCoordinates
        /// A general error
        case notParsable
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case coordinates
    }
    
    /// Decodes JSON or similarly structured decoders
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try values.decode(String.self, forKey: .type)
        switch typeString {
        case "Point":
            let coord = try values.decode([Double].self, forKey: .coordinates)
            guard let x = GeoJsonGeometry.toCoordinate(coord) else {
                throw GeoJsonGeometryError.invalidCoordinates
            }
            self = .point(coordinates: x)
        case "LineString":
            let coords = try values.decode([[Double]].self, forKey: .coordinates)
            guard let x = GeoJsonGeometry.toCoordinates(coords), x.count >= 2 else {
                throw GeoJsonGeometryError.invalidCoordinates
            }
            self = .lineString(coordinates: x)
        case "MultiPoint":
            let coords = try values.decode([[Double]].self, forKey: .coordinates)
            guard let x = GeoJsonGeometry.toCoordinates(coords), x.count > 0 else {
                throw GeoJsonGeometryError.invalidCoordinates
            }
            self = .multiPoint(coordinates: x)
        case "Polygon":
            // Ensuring correctness: https://datatracker.ietf.org/doc/html/rfc7946#section-3.1.6
            let coords = try values.decode([[[Double]]].self, forKey: .coordinates)
            guard let x = GeoJsonGeometry.toCoordinates(coords),
                  x.first?.first != nil,
                  x.allSatisfy({ $0.count >= 4 && $0.first == $0.last }) else {
                throw GeoJsonGeometryError.invalidCoordinates
            }
            self = .polygon(coordinates: x)
        case "MultiLineString":
            let coords = try values.decode([[[Double]]].self, forKey: .coordinates)
            guard let x = GeoJsonGeometry.toCoordinates(coords),
                  x.count > 0, x.allSatisfy({ $0.count >= 2 }) else {
                throw GeoJsonGeometryError.invalidCoordinates
            }
            self = .multiLineString(coordinates: x)
        case "MultiPolygon":
            let coords = try values.decode([[[[Double]]]].self, forKey: .coordinates)
            guard let x = GeoJsonGeometry.toCoordinates(coords),
                  x.first?.first?.first != nil else {
                throw GeoJsonGeometryError.invalidCoordinates
            }
            self = .multiPolygon(coordinates: x)
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: values.codingPath, debugDescription: "Invalid GeoJsonGeometry type \"\(typeString)\""))
        }
    }
    
    public init?(geoJSON: String) {
        guard let data = geoJSON.data(using: .utf8),
              let json = try? JSONDecoder().decode(GeoJsonGeometry.self, from: data) else {
            return nil
        }
        self = json
    }
    
    public init(point: CLLocationCoordinate2D) {
        self = .point(coordinates: point)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.rawValue, forKey: .type)
        switch self {
        case .point(coordinates: let coordinates):
            try container.encode([coordinates.longitude, coordinates.latitude], forKey: .coordinates)
        case .lineString(coordinates: let coordinates), .multiPoint(coordinates: let coordinates):
            let expanded = coordinates.map(GeoJsonGeometry.into_coord_pair)
            try container.encode(expanded, forKey: .coordinates)
        case .polygon(coordinates: let coordinates), .multiLineString(coordinates: let coordinates):
            let expanded = coordinates.map({$0.map(GeoJsonGeometry.into_coord_pair)})
            try container.encode(expanded, forKey: .coordinates)
        case .multiPolygon(coordinates: let coordinates):
            let expanded = coordinates.map({$0.map({$0.map(GeoJsonGeometry.into_coord_pair)})})
            try container.encode(expanded, forKey: .coordinates)
        }
    }
    
    /// note: the centroid is based on the implementation in ``GeometryUtils`` and may have any of the same issues.
    var centroid: CLLocationCoordinate2D {
        switch self {
        case .point(coordinates: let coordinates):
            return coordinates
        case .lineString(coordinates: let coordinates), .multiPoint(coordinates: let coordinates):
            return GeometryUtils.centroid(coordinates: coordinates)!
        case .polygon(coordinates: let coordinates), .multiLineString(coordinates: let coordinates):
            return GeometryUtils.centroid(coordinates: coordinates.flatMap({$0}))!
        case .multiPolygon(coordinates: let coordinates):
            return GeometryUtils.centroid(coordinates: coordinates.flatMap({$0.flatMap({$0})}))!
        }
    }
    
    /// Finds the median point in the list of points, or if there are an even number of points, gets the mid point between the two median points. Returns nil if the geometry isn't a LineString
    func getLineMedian() -> CLLocationCoordinate2D? {
        guard case .lineString(coordinates: let coordinates) = self else {
            return nil
        }
        
        guard !coordinates.isEmpty else {
            return nil
        }
        
        if coordinates.count % 2 == 1 {
            return coordinates[coordinates.count / 2]
        }
        
        let first = coordinates[(coordinates.count / 2) - 1]
        let last = coordinates[coordinates.count / 2]
        return first.coordinateBetween(coordinate: last, distance: first.distance(from: last) / 2)
    }
    
    /// Find the very first point - in the typical line case, this works just fine. In the multipolygon sort of case, this will be weird
    var first: CLLocationCoordinate2D {
        switch self {
        case .point(coordinates: let coordinates):
            return coordinates
        case .lineString(coordinates: let coordinates):
            return coordinates.first!
        case .multiPoint(coordinates: let coordinates):
            return coordinates.first!
        case .polygon(coordinates: let coordinates):
            return coordinates.first!.first!
        case .multiLineString(coordinates: let coordinates):
            return coordinates.first!.first!
        case .multiPolygon(coordinates: let coordinates):
            return coordinates.first!.first!.first!
        }
    }
    
    /// Find the very last point - in the typical line case, this works just fine. In the multipolygon sort of case, this will be weird
    var last: CLLocationCoordinate2D {
        switch self {
        case .point(coordinates: let coordinates):
            return coordinates
        case .lineString(coordinates: let coordinates):
            return coordinates.last!
        case .multiPoint(coordinates: let coordinates):
            return coordinates.last!
        case .polygon(coordinates: let coordinates):
            return coordinates.last!.last!
        case .multiLineString(coordinates: let coordinates):
            return coordinates.last!.last!
        case .multiPolygon(coordinates: let coordinates):
            return coordinates.last!.last!.last!
        }
    }
    
    var coordinates: Any {
        switch self {
        case .point(coordinates: let coordinates):
            return coordinates
        case .lineString(coordinates: let coordinates):
            return coordinates
        case .multiPoint(coordinates: let coordinates):
            return coordinates
        case .polygon(coordinates: let coordinates):
            return coordinates
        case .multiLineString(coordinates: let coordinates):
            return coordinates
        case .multiPolygon(coordinates: let coordinates):
            return coordinates
        }
        
    }
    
    /// If the geometry contains the point.
    /// Since only `polygon` and `multiPolygon` geometries have any area (and thus contain stuff), all other geometry types will return false.
    ///
    /// true if within the region of the first (outer) ring, but none of the other rings (holes)
    func withinArea(_ point: CLLocationCoordinate2D) -> Bool {
        switch self {
        case .polygon(coordinates: let coordinates):
            guard GeometryUtils.geometryContainsLocation(location: point, coordinates: coordinates.first!) else {
                return false
            }
            for i in 1..<coordinates.count {
                if GeometryUtils.geometryContainsLocation(location: point, coordinates: coordinates[i]) {
                    return false
                }
            }
            return true
        case .multiPolygon(coordinates: let polys):
            return polys.contains(where: { poly in
                guard GeometryUtils.geometryContainsLocation(location: point, coordinates: poly.first!) else {
                    return false
                }
                for i in 1..<poly.count {
                    if GeometryUtils.geometryContainsLocation(location: point, coordinates: poly[i]) {
                        return false
                    }
                }
                return true
            })
        default:
            return false
        }
    }
    
    /// Finds the closest point on the edge of this geometry to the specified point
    /// This includes all lines and rings in the geometry.
    func closestEdge(to point: CLLocationCoordinate2D) -> CLLocationCoordinate2D? {
        switch self {
        case .point(coordinates: let coordinates):
            return coordinates
        case .lineString(coordinates: let coordinates), .multiPoint(coordinates: let coordinates):
            return GeometryUtils.closestEdge(from: point, on: coordinates)
        case .polygon(coordinates: let coordinates), .multiLineString(coordinates: let coordinates):
            var closestLocation: CLLocationCoordinate2D? = nil
            var minimumDistance = CLLocationDistanceMax
            for line in coordinates {
                guard let closest = GeometryUtils.closestEdge(from: point, on: line) else {
                    continue
                }
                let distance = closest.distance(from: point)
                if distance < minimumDistance {
                    closestLocation = closest
                    minimumDistance = distance
                }
            }
            return closestLocation
        case .multiPolygon(coordinates: let coordinates):
            var closestLocation: CLLocationCoordinate2D? = nil
            var minimumDistance = CLLocationDistanceMax
            for polygon in coordinates {
                for line in polygon {
                    guard let closest = GeometryUtils.closestEdge(from: point, on: line) else {
                        continue
                    }
                    let distance = closest.distance(from: point)
                    if distance < minimumDistance {
                        closestLocation = closest
                        minimumDistance = distance
                    }
                }
            }
            return closestLocation
        }
    }
}


// MARK: Conversion Functions

extension GeoJsonGeometry {
    private static func into_coord_pair(_ coord: CLLocationCoordinate2D) -> [CLLocationDegrees] {
        return [coord.latitude, coord.longitude]
    }
    
    
    
    /// Transform to a `CLLocationCoordinate2D` object.
    private static func toCoordinate(_ arr: [Double]?) -> CLLocationCoordinate2D? {
        guard let arr = arr, arr.count >= 2 else {
            return nil
        }
        return CLLocationCoordinate2DMake(arr[1], arr[0])
    }
    /// Transform to an array of `CLLocationCoordinate2D` objects.
    private static func toCoordinates(_ arr: [[Double]]?) -> [CLLocationCoordinate2D]? {
        guard let arr = arr else {
            return nil
        }
        return try? arr.map({ (point) -> CLLocationCoordinate2D in
            guard let coord = toCoordinate(point) else {
                throw GeoJsonGeometryError.notParsable
            }
            return coord
        })
    }
    /// Transform to an array of `CLLocationCoordinate2D` objects.
    private static func toCoordinates(_ arr: [[[Double]]]?) -> [[CLLocationCoordinate2D]]? {
        guard let arr = arr else {
            return nil
        }
        return try? arr.map({ (point) -> [CLLocationCoordinate2D] in
            guard let coord = toCoordinates(point) else {
                throw GeoJsonGeometryError.notParsable
            }
            return coord
        })
    }
    /// Transform to an array of `CLLocationCoordinate2D` objects.
    private static func toCoordinates(_ arr: [[[[Double]]]]?) -> [[[CLLocationCoordinate2D]]]? {
        guard let arr = arr else {
            return nil
        }
        return try? arr.map({ (point) -> [[CLLocationCoordinate2D]] in
            guard let coord = toCoordinates(point) else {
                throw GeoJsonGeometryError.notParsable
            }
            return coord
        })
    }
}
