// Copyright (c) Soundscape Community Contributers.

import Foundation
import SSGeo

public enum GeometryType: Int, RawRepresentable, Sendable {
    case point
    case lineString
    case multiPoint
    case polygon
    case multiLineString
    case multiPolygon

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

    public init?(rawValue: RawValue) {
        switch rawValue {
        case "Point":
            self = .point
        case "LineString":
            self = .lineString
        case "MultiPoint":
            self = .multiPoint
        case "Polygon":
            self = .polygon
        case "MultiLineString":
            self = .multiLineString
        case "MultiPolygon":
            self = .multiPolygon
        default:
            self = .multiPolygon
        }
    }
}

public typealias GAPoint = [Double]
public typealias GALine = [GAPoint]
public typealias GAMultiLine = [GALine]
public typealias GAMultiLineCollection = [GAMultiLine]

public enum GeoJSONGeometryParser {
    public static func coordinates(geoJson: String) -> (type: GeometryType?, points: [Any]?) {
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

    public static func centroid(geoJson: String) -> SSGeoCoordinate? {
        guard let points = coordinates(geoJson: geoJson).points else {
            return nil
        }

        if let point = points as? GAPoint {
            return point.toSSGeoCoordinate()
        }

        if let points = points as? GALine {
            return SSGeoPath.centroid(coordinates: points.toSSGeoCoordinates())
        }

        if let points = points as? GAMultiLine {
            let flattened = Array(points.toSSGeoCoordinates().joined())
            return SSGeoPath.centroid(coordinates: flattened)
        }

        return nil
    }
}

public extension Array where Element == Double {
    func toSSGeoCoordinate() -> SSGeoCoordinate {
        SSGeoCoordinate(latitude: self[1], longitude: self[0])
    }
}

public extension Array where Element == [Double] {
    func toSSGeoCoordinates() -> [SSGeoCoordinate] {
        map { $0.toSSGeoCoordinate() }
    }
}

public extension Array where Element == [[Double]] {
    func toSSGeoCoordinates() -> [[SSGeoCoordinate]] {
        map { $0.toSSGeoCoordinates() }
    }
}

public extension Array where Element == [[[Double]]] {
    func toSSGeoCoordinates() -> [[[SSGeoCoordinate]]] {
        map { $0.toSSGeoCoordinates() }
    }
}
