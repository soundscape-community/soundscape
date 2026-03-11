// Copyright (c) Soundscape Community Contributers.

import Foundation
import SSGeo

public final class VectorTile: Hashable {
    public enum VectorTileError: Error {
        case zoomValueOutOfRange
        case invalidQuadKeySequence
    }

    public static let earthRadius = Int(SSGeoMercator.earthRadiusMeters)
    public static let minLatitude = SSGeoMercator.minLatitude
    public static let maxLatitude = SSGeoMercator.maxLatitude
    public static let minLongitude = SSGeoMercator.minLongitude
    public static let maxLongitude = SSGeoMercator.maxLongitude

    public let x: Int
    public let y: Int
    public let zoom: UInt
    public let quadKey: String
    public let id: String

    public var polygon: [SSGeoCoordinate] {
        let (startPixelX, startPixelY) = Self.getPixelXY(tileX: x, tileY: y)
        let (endPixelX, endPixelY) = Self.getPixelXY(tileX: x + 1, tileY: y + 1)

        let (startLat, startLon) = Self.getLatLong(pixelX: startPixelX, pixelY: startPixelY, zoom: zoom)
        let (endLat, endLon) = Self.getLatLong(pixelX: endPixelX, pixelY: endPixelY, zoom: zoom)

        return [
            SSGeoCoordinate(latitude: startLat, longitude: startLon),
            SSGeoCoordinate(latitude: startLat, longitude: endLon),
            SSGeoCoordinate(latitude: endLat, longitude: endLon),
            SSGeoCoordinate(latitude: endLat, longitude: startLon),
            SSGeoCoordinate(latitude: startLat, longitude: startLon),
        ]
    }

    public init(JSON json: GDAJSONObject) {
        x = json.number(atPath: "X")!.intValue
        y = json.number(atPath: "Y")!.intValue
        zoom = json.number(atPath: "ZoomLevel")!.uintValue
        quadKey = json.string(atPath: "QuadKey")!
        id = json.string(atPath: "Id")!
    }

    public init(coordinate: SSGeoCoordinate, zoom zoomLevel: UInt) {
        let (pixelX, pixelY) = Self.getPixelXY(latitude: coordinate.latitude,
                                               longitude: coordinate.longitude,
                                               zoom: zoomLevel)
        let (tileX, tileY) = Self.getTileXY(pixelX: pixelX, pixelY: pixelY)

        x = tileX
        y = tileY
        zoom = zoomLevel

        do {
            let key = try Self.getQuadKey(tileX: tileX, tileY: tileY, zoom: zoomLevel)
            quadKey = key
            id = key
        } catch {
            quadKey = ""
            id = ""
        }
    }

    public convenience init(latitude lat: Double, longitude lon: Double, zoom zoomLevel: UInt) {
        self.init(coordinate: SSGeoCoordinate(latitude: lat, longitude: lon), zoom: zoomLevel)
    }

    public init(tileX: Int, tileY: Int, zoom zoomLevel: UInt) {
        x = tileX
        y = tileY
        zoom = zoomLevel

        do {
            let key = try Self.getQuadKey(tileX: tileX, tileY: tileY, zoom: zoomLevel)
            quadKey = key
            id = key
        } catch {
            quadKey = ""
            id = ""
        }
    }

    public init(quadKey quad: String) {
        do {
            (x, y, zoom) = try Self.getTileXYZ(quadkey: quad)
        } catch {
            x = -1
            y = -1
            zoom = 0
        }

        quadKey = quad
        id = quad
    }

    public static func == (lhs: VectorTile, rhs: VectorTile) -> Bool {
        lhs.x == rhs.x && lhs.y == rhs.y && lhs.zoom == rhs.zoom
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
        hasher.combine(zoom)
    }

    public static func tilesForRegion(_ location: SSGeoLocation, radiusMeters: Double, zoom zoomLevel: UInt) -> [VectorTile] {
        let (pixelX, pixelY) = getPixelXY(latitude: location.coordinate.latitude,
                                          longitude: location.coordinate.longitude,
                                          zoom: zoomLevel)
        let radiusPixels = Int(radiusMeters / groundResolution(latitude: location.coordinate.latitude, zoom: zoomLevel))

        let startX = pixelX - radiusPixels
        let startY = pixelY - radiusPixels
        let endX = pixelX + radiusPixels
        let endY = pixelY + radiusPixels

        let (startTileX, startTileY) = getTileXY(pixelX: startX, pixelY: startY)
        let (endTileX, endTileY) = getTileXY(pixelX: endX, pixelY: endY)

        var tiles: [VectorTile] = []
        for y in startTileY...endTileY {
            for x in startTileX...endTileX {
                tiles.append(VectorTile(tileX: x, tileY: y, zoom: zoomLevel))
            }
        }

        return tiles
    }

    public static func tileForLocation(_ location: SSGeoLocation, zoom zoomLevel: UInt) -> VectorTile {
        let (pixelX, pixelY) = getPixelXY(latitude: location.coordinate.latitude,
                                          longitude: location.coordinate.longitude,
                                          zoom: zoomLevel)
        let (x, y) = getTileXY(pixelX: pixelX, pixelY: pixelY)
        return VectorTile(tileX: x, tileY: y, zoom: zoomLevel)
    }

    public static func clip(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        SSGeoMercator.clip(value, min: minimum, max: maximum)
    }

    public static func mapSize(zoom: UInt) -> UInt {
        SSGeoMercator.mapSize(zoom: zoom)
    }

    public static func groundResolution(latitude: Double, zoom: UInt) -> Double {
        SSGeoMercator.groundResolution(latitude: latitude, zoom: zoom)
    }

    public static func getPixelXY(latitude: Double, longitude: Double, zoom zoomLevel: UInt) -> (x: Int, y: Int) {
        SSGeoMercator.pixelXY(
            for: SSGeoCoordinate(latitude: latitude, longitude: longitude),
            zoom: zoomLevel
        )
    }

    public static func getLatLong(pixelX: Int, pixelY: Int, zoom zoomLevel: UInt) -> (lat: Double, lon: Double) {
        let coordinate = SSGeoMercator.coordinate(forPixelX: pixelX, pixelY: pixelY, zoom: zoomLevel)
        return (coordinate.latitude, coordinate.longitude)
    }

    public static func getTileXY(pixelX: Int, pixelY: Int) -> (x: Int, y: Int) {
        SSGeoMercator.tileXY(pixelX: pixelX, pixelY: pixelY)
    }

    public static func getPixelXY(tileX: Int, tileY: Int) -> (x: Int, y: Int) {
        SSGeoMercator.pixelXY(tileX: tileX, tileY: tileY)
    }

    public static func isValidLocation(latitude: Double, longitude: Double) -> Bool {
        guard latitude >= minLatitude, latitude <= maxLatitude else {
            return false
        }

        guard longitude >= minLongitude, longitude <= maxLongitude else {
            return false
        }

        return true
    }

    public static func isValidTile(x tileX: Int, y tileY: Int, zoom zoomLevel: UInt) -> Bool {
        let size = Int(mapSize(zoom: zoomLevel) / 256)
        return tileX >= 0 && tileX < size && tileY >= 0 && tileY < size
    }

    public static func getQuadKey(tileX: Int, tileY: Int, zoom zoomLevel: UInt) throws -> String {
        guard zoomLevel > 0 && zoomLevel < 24 else {
            throw VectorTileError.zoomValueOutOfRange
        }

        var quadKey = ""
        for level in (1...Int(zoomLevel)).reversed() {
            var digit = 0
            let mask = 1 << (level - 1)

            if (tileX & mask) != 0 {
                digit += 1
            }

            if (tileY & mask) != 0 {
                digit += 2
            }

            quadKey += String(digit)
        }

        return quadKey
    }

    public static func getTileXYZ(quadkey: String) throws -> (x: Int, y: Int, zoom: UInt) {
        var x = 0
        var y = 0
        let zoom = quadkey.count

        for level in (1...zoom).reversed() {
            let mask = 1 << (level - 1)
            let index = quadkey.index(quadkey.startIndex, offsetBy: zoom - level)

            switch quadkey[index] {
            case "0":
                break
            case "1":
                x |= mask
            case "2":
                y |= mask
            case "3":
                x |= mask
                y |= mask
            default:
                throw VectorTileError.invalidQuadKeySequence
            }
        }

        return (x, y, UInt(zoom))
    }
}
