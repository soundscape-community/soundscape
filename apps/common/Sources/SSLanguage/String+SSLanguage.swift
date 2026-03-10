// Copyright (c) Soundscape Community Contributers.

import Foundation

extension String {
    func ssSubstring(from: Int, to: Int) -> String? {
        guard from < count, to < count, to - from >= 0 else {
            return nil
        }

        let startIndex = index(self.startIndex, offsetBy: from)
        let endIndex = index(self.startIndex, offsetBy: to)
        return String(self[startIndex...endIndex])
    }
}

extension String {
    private static let stringArgumentRegexPattern = #"%@|%(\d+)\$@"#

    private var argumentCount: Int {
        guard let regex = try? NSRegularExpression(pattern: String.stringArgumentRegexPattern) else {
            return 0
        }

        return regex.numberOfMatches(in: self, range: NSRange(location: 0, length: count))
    }

    init(normalizedArgsWithFormat format: String, arguments: [String]) {
        let formatArgCount = format.argumentCount

        guard formatArgCount != arguments.count else {
            self.init(format: format, arguments: arguments)
            return
        }

        guard formatArgCount > 0 else {
            self.init(format: format)
            return
        }

        let preciseArgs: [String]
        if formatArgCount < arguments.count {
            preciseArgs = Array(arguments[0..<formatArgCount])
        } else {
            preciseArgs = arguments + Array(repeating: "(null)", count: formatArgCount - arguments.count)
        }

        self.init(format: format, arguments: preciseArgs)
    }
}
