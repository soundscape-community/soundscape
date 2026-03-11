//
//  GeoJsonGeometry.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import Foundation
import SSDataContracts

typealias GeometryType = SSDataContracts.GeometryType
typealias GAPoint = SSDataContracts.GAPoint
typealias GALine = SSDataContracts.GALine
typealias GAMultiLine = SSDataContracts.GAMultiLine
typealias GAMultiLineCollection = SSDataContracts.GAMultiLineCollection

/// GeoJsonGeometry is a Swift representation of the `geometry` property in a GeoJSON feature.
class GeoJsonGeometry {
    
    /// Type of this geometry from the parsed GeoJSON
    private(set) var type: GeometryType
    
    /// String encoding of the coordinates in this geometry
    private(set) var coordinateJSON: String
    
    /// Coordinates from the parsed GeoJSON
    private(set) var coordinates: [[[[Double]]]]?
    
    /// A single lat/lon coordinate in the case self.type is `Point`
    var point: [Double]? {
        guard type == .point else {
            return nil
        }
        
        return coordinates?[0][0][0]
    }
    
    /// An array of points in the case self.type is `LineString` or `MultiPoint`
    var points: [[Double]]? {
        guard type == .lineString || type == .multiPoint else {
            return nil
        }
        
        return coordinates?[0][0]
    }
    
    /// An array of lines in the case self.type is `Polygon` or `MultiLineString`
    var polygon: [[[Double]]]? {
        guard type == .polygon || type == .multiLineString else {
            return nil
        }
        
        return coordinates?[0]
    }
    
    /// An array of polygons in the case self.type is `MultiPolygon`
    var multipolygon: [[[[Double]]]]? {
        guard type == .multiPolygon else {
            return nil
        }
        
        return coordinates
    }
    
    /// The geometry's centroid, represented as `[longitude, latitude]`
    var centroid: [Double]? {
        guard let points = coordinates else {
            return nil
        }
        
        let flattenedCoordinates = Array(points.toCoordinates().joined().joined())
        guard let centroid = GeometryUtils.centroid(coordinates: flattenedCoordinates) else {
            return nil
        }
        
        return [centroid.longitude, centroid.latitude]
    }
    
    init?(geoJSON: [String: Any]) {
        // Parse the geometry type
        guard let typeString = geoJSON["type"] as? String else {
            return nil
        }
        
        guard let parsedType = GeometryType(rawValue: typeString) else {
            return nil
        }
        
        type = parsedType
        
        // Save the coordinates JSON
        do {
            let data = try JSONSerialization.data(withJSONObject: geoJSON)
            coordinateJSON = String(data: data, encoding: String.Encoding.utf8)!
        } catch {
            return nil
        }
        
        switch type {
        case .point:
            if let pt = geoJSON["coordinates"] as? [Double] {
                coordinates = [[[pt]]]
            }
        case .lineString:
            if let ln = geoJSON["coordinates"] as? [[Double]] {
                coordinates = [[ln]]
            }
        case .multiPoint:
            if let ln = geoJSON["coordinates"] as? [[Double]] {
                coordinates = [[ln]]
            }
        case .polygon:
            if let poly = geoJSON["coordinates"] as? [[[Double]]] {
                coordinates = [poly]
            }
        case .multiLineString:
            if let poly = geoJSON["coordinates"] as? [[[Double]]] {
                coordinates = [poly]
            }
        case .multiPolygon:
            if let poly = geoJSON["coordinates"] as? [[[[Double]]]] {
                coordinates = poly
            }
        }
        
        // Validate that the provided coordinates are valid and not malformed
        guard validate() else {
            return nil
        }
    }
    
    init?(point: [Double]) {
        guard point.count == 2 else {
            return nil
        }
        
        type = .point
        coordinates = [[[point]]]
        coordinateJSON = "{\"coordinates\": [\(point[0]),\(point[1])], \"type\": \"Point\"}"
    }

    init?(copyFrom: GeoJsonGeometry?) {
        guard let copy = copyFrom else {
            return nil
        }
        
        self.type = copy.type
        self.coordinateJSON = copy.coordinateJSON
        self.coordinates = copy.coordinates
    }
    
    func validate() -> Bool {
        switch type {
        case .point:
            // A point must have 2 values (lat, lon)
            if let point = point, point.count == 2 {
                return true
            }
            
        case .lineString, .multiPoint:
            // A lineString or multiPoint geometry must have 1 or more points and those points must have 2 values (lat, lon)
            if let points = points, points.count > 0 {
                return !points.contains(where: { $0.count != 2 })
            }
            
        case .polygon, .multiLineString:
            // A polygon or multiLineString geometry must have 1 or more linesStrings, each with 1 or more points, and those points must have 2 values (lat, lon)
            if let polygon = polygon, polygon.count > 0 {
                return !polygon.contains(where: { (points) -> Bool in
                    return points.count == 0 || points.contains(where: { $0.count != 2})
                })
            }
            
        case .multiPolygon:
            // A multipolygon geometry must have 1 or more polygons, each with 1 or more linesStrings, each with 1 or more points, and those points must have 2 values (lat, lon)
            if let multipolygon = multipolygon, multipolygon.count > 0 {
                return !multipolygon.contains(where: { (polygon) -> Bool in
                    return polygon.count == 0 || polygon.contains(where: { (points) -> Bool in
                        return points.count == 0 || points.contains(where: { $0.count != 2 })
                    })
                })
            }
        }
        
        return false
    }
    
    /// Finds the median point in the list of points, or if there are an even number of points, gets the mid point between the two median points. Returns nil if the geometry isn't a LineString
    func getLineMedian() -> [Double]? {
        guard type == .lineString else {
            return nil
        }
        
        guard let pts = coordinates?[0][0] else {
            return nil
        }
        
        guard pts.count > 1 else {
            if pts.count == 1 {
                return pts[0]
            }
            
            return nil
        }
        
        if pts.count % 2 == 1 {
            return pts[pts.count / 2]
        }
        
        let first = pts[(pts.count / 2) - 1]
        let last = pts[pts.count / 2]
        
        let toRadians = .pi / 180.0
        let toDegrees = 180.0 / .pi
        
        let phi1 = first[1] * toRadians
        let phi2 = last[1] * toRadians
        let lambda1 = first[0] * toRadians
        let lambda2 = last[0] * toRadians
        
        let bX = cos(phi2) * cos(lambda2 - lambda1)
        let bY = cos(phi2) * sin(lambda2 - lambda1)
        let lat = toDegrees * atan2(sin(phi1) + sin(phi2), sqrt((cos(phi1) + bX) * (cos(phi1) + bX) + bY * bY))
        let lon = fmod((lambda1 + atan2(bY, cos(phi1) + bX)) * toDegrees + 540, 360.0) - 180.0
        
        return [lon, lat]
    }
    
    func clipToFirstPoint() -> Bool {
        guard let firstPoint = coordinates?[0][0][0] else {
            return false
        }
        
        do {
            let jsonObj = try JSONSerialization.data(withJSONObject: ["coordinates": firstPoint, "type": "Point"])
            
            guard let jsonStr = String(data: jsonObj, encoding: String.Encoding.utf8) else {
                return false
            }
            
            // We were able to properly encode the new clipped geometry, so update everything
            type = .point
            coordinates = [[[firstPoint]]]
            coordinateJSON = jsonStr
        } catch {
            return false
        }
        
        return true
    }
    
    func clipToLastPoint() -> Bool {
        // Find the very last point - in the typical line case, this works just fine. In the multipolygon sort of case, this will be weird
        guard let firstIdx = coordinates?.count else {
            return false
        }
        
        guard let secondIdx = coordinates?[firstIdx - 1].count else {
            return false
        }
        
        guard let thirdIdx = coordinates?[firstIdx - 1][secondIdx - 1].count else {
            return false
        }
        
        guard let lastPoint = coordinates?[firstIdx - 1][secondIdx - 1][thirdIdx - 1] else {
            return false
        }
        
        do {
            let jsonObj = try JSONSerialization.data(withJSONObject: ["coordinates": lastPoint, "type": "Point"])
            
            guard let jsonStr = String(data: jsonObj, encoding: String.Encoding.utf8) else {
                return false
            }
            
            // We were able to properly encode the new clipped geometry, so update everything
            type = .point
            coordinates = [[[lastPoint]]]
            coordinateJSON = jsonStr
        } catch {
            return false
        }
        
        return true
    }
}
