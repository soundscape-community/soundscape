// Copyright (c) Soundscape Community Contributers.

import Foundation
import SSGeo

public struct CodeableDirection: Sendable {
    fileprivate struct Delimiter {
        static let start = "@!"
        static let end = "!!"
        static let separator = ","
    }

    fileprivate static let regexPattern = Delimiter.start + "[^>]+" + Delimiter.end

    public typealias Result = (direction: Direction, encodedSubstring: String, range: NSRange)

    public enum DecodingError: Error {
        case noDirectionFound
        case invalidOrigin(Result)
        case invalidCoordinateOrHeading
        case parsingError(String)
    }

    public let originCoordinate: SSGeoCoordinate?
    public let originHeading: Double?
    public let destinationCoordinate: SSGeoCoordinate
    public let directionType: RelativeDirectionType

    public init(
        originCoordinate: SSGeoCoordinate? = nil,
        originHeading: Double? = nil,
        destinationCoordinate: SSGeoCoordinate,
        directionType: RelativeDirectionType = .combined
    ) {
        self.originCoordinate = originCoordinate
        self.originHeading = originHeading
        self.destinationCoordinate = destinationCoordinate
        self.directionType = directionType
    }

    public init?(string: String) {
        let components = string.components(separatedBy: Delimiter.separator)
        guard components.count == 3 || components.count == 6 else {
            return nil
        }

        guard
            let destinationLatitude = Double(components[0]),
            let destinationLongitude = Double(components[1]),
            let directionType = RelativeDirectionType(rawValue: Int(components[2]) ?? -1)
        else {
            return nil
        }

        let destinationCoordinate = SSGeoCoordinate(latitude: destinationLatitude, longitude: destinationLongitude)
        guard destinationCoordinate.isValidLocationCoordinate else {
            return nil
        }

        let originCoordinate: SSGeoCoordinate?
        let originHeading: Double?
        if components.count == 6 {
            guard
                let originLatitude = Double(components[3]),
                let originLongitude = Double(components[4]),
                let resolvedOriginHeading = Double(components[5])
            else {
                return nil
            }

            let resolvedOrigin = SSGeoCoordinate(latitude: originLatitude, longitude: originLongitude)
            guard resolvedOrigin.isValidLocationCoordinate else {
                return nil
            }

            originCoordinate = resolvedOrigin
            originHeading = resolvedOriginHeading
        } else {
            originCoordinate = nil
            originHeading = nil
        }

        self.originCoordinate = originCoordinate
        self.originHeading = originHeading
        self.destinationCoordinate = destinationCoordinate
        self.directionType = directionType
    }

    public func encode() -> String {
        let userInfo: String
        if let originCoordinate, let originHeading {
            userInfo = Delimiter.separator + "\(originCoordinate.latitude)" +
                Delimiter.separator + "\(originCoordinate.longitude)" +
                Delimiter.separator + "\(originHeading)"
        } else {
            userInfo = ""
        }

        return Delimiter.start + "\(destinationCoordinate.latitude)" +
            Delimiter.separator + "\(destinationCoordinate.longitude)" +
            Delimiter.separator + "\(directionType.rawValue)\(userInfo)" + Delimiter.end
    }

    public static func decode(
        string: String,
        originCoordinate: SSGeoCoordinate? = nil,
        originHeading: Double? = nil
    ) throws -> Result {
        let codedDirection = try string.codedDirectionSubstring()

        do {
            let direction = try codedDirection.string.decodeDirection(
                originCoordinate: originCoordinate,
                originHeading: originHeading
            )
            return (direction, codedDirection.string, codedDirection.range)
        } catch DecodingError.invalidCoordinateOrHeading {
            let result: Result = (.unknown, codedDirection.string, codedDirection.range)
            throw DecodingError.invalidOrigin(result)
        }
    }
}

extension String {
    fileprivate func codedDirectionSubstring() throws -> (string: String, range: NSRange) {
        guard !isEmpty else {
            throw CodeableDirection.DecodingError.noDirectionFound
        }

        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: CodeableDirection.regexPattern)
        } catch {
            throw CodeableDirection.DecodingError.parsingError("Failed to create regex object")
        }

        guard let match = regex.firstMatch(in: self, range: NSRange(location: 0, length: count)) else {
            throw CodeableDirection.DecodingError.noDirectionFound
        }

        guard let substring = ssSubstring(from: match.range.location, to: match.range.location + match.range.length - 1) else {
            throw CodeableDirection.DecodingError.parsingError("Invalid relative direction substring")
        }

        return (substring, match.range)
    }

    fileprivate func decodeDirection(
        originCoordinate: SSGeoCoordinate?,
        originHeading: Double?
    ) throws -> Direction {
        let cleaned = replacingOccurrences(of: CodeableDirection.Delimiter.start, with: "")
            .replacingOccurrences(of: CodeableDirection.Delimiter.end, with: "")

        guard let codeableDirection = CodeableDirection(string: cleaned) else {
            throw CodeableDirection.DecodingError.parsingError("Invalid format for: \(self)")
        }

        let resolvedOriginCoordinate = codeableDirection.originCoordinate ?? originCoordinate
        let resolvedOriginHeading = codeableDirection.originHeading ?? originHeading

        guard let resolvedOriginCoordinate, let resolvedOriginHeading else {
            throw CodeableDirection.DecodingError.invalidCoordinateOrHeading
        }

        let bearing = resolvedOriginCoordinate.initialBearing(to: codeableDirection.destinationCoordinate)
        return Direction(from: resolvedOriginHeading, to: bearing, type: codeableDirection.directionType)
    }
}

extension SSGeoCoordinate {
    fileprivate var isValidLocationCoordinate: Bool {
        isValid && !(latitude == 0.0 && longitude == 0.0)
    }
}
