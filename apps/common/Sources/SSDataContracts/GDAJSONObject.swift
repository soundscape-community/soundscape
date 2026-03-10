// Copyright (c) Soundscape Community Contributers.

import Foundation

public final class GDAJSONObject {
    public let object: Any
    public let isArray: Bool

    public var jsonString: String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: []),
              let string = String(data: data, encoding: .utf8) else {
            return isArray ? "[]" : "{}"
        }

        return string
    }

    public init?(data: Data) {
        guard let deserialized = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return nil
        }

        self.object = deserialized
        self.isArray = deserialized is [Any]
    }

    public init?(object: Any) {
        self.object = object
        self.isArray = object is [Any]
    }

    public convenience init?(string: String) {
        guard let data = string.data(using: .utf8) else {
            return nil
        }

        self.init(data: data)
    }

    public func array(atPath path: String) -> [Any]? {
        value(atPath: path, as: [Any].self)
    }

    public func string(atPath path: String) -> String? {
        value(atPath: path, as: String.self)
    }

    public func number(atPath path: String) -> NSNumber? {
        value(atPath: path, as: NSNumber.self)
    }

    public func object(atPath path: String) -> GDAJSONObject? {
        guard let dictionary = value(atPath: path, as: [String: Any].self) else {
            return nil
        }

        return GDAJSONObject(object: dictionary)
    }

    public func firstArrayElement(withPropertyName propertyName: String,
                                  equalToPropertyValue propertyValue: Any) -> GDAJSONObject? {
        guard let propertyValue = propertyValue as? String,
              let array = object as? [Any] else {
            return nil
        }

        for entry in array {
            guard let dictionary = entry as? [String: Any],
                  let candidate = dictionary[propertyName] as? String,
                  candidate == propertyValue else {
                continue
            }

            return GDAJSONObject(object: dictionary)
        }

        return nil
    }

    private func value<T>(atPath path: String, as type: T.Type) -> T? {
        let resolvedValue: Any?
        if path.isEmpty {
            resolvedValue = object
        } else {
            resolvedValue = navigate(path: path)
        }

        return resolvedValue as? T
    }

    private func navigate(path: String) -> Any? {
        var current: Any? = object

        for segment in path.split(separator: ".").map(String.init) {
            guard let unwrapped = current else {
                return nil
            }

            if let index = Int(segment) {
                guard index >= 0,
                      let array = unwrapped as? [Any],
                      array.indices.contains(index) else {
                    return nil
                }

                current = array[index]
                if current is NSNull {
                    current = nil
                }
                continue
            }

            guard let dictionary = unwrapped as? [String: Any] else {
                return nil
            }

            current = dictionary[segment]
            if current is NSNull {
                current = nil
            }
        }

        return current
    }
}
