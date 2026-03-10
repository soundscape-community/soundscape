// Copyright (c) Soundscape Community Contributers.

import Foundation
import SSDataStructures

extension String {
    private static var whitespace: String {
        " "
    }

    private func tokenize(separatedBy separator: String = String.whitespace) -> Token {
        Token(string: lowercased(), separatedBy: separator)
    }

    func tokenSort(other: String) -> Double {
        let tokenA = tokenize()
        let tokenB = other.tokenize()

        return tokenA.tokenizedString.weightedMinimumEditDistance(other: tokenB.tokenizedString)
    }

    func tokenSet(other: String) -> Double {
        let tokenA = tokenize()
        let tokenB = other.tokenize()
        let intersection = tokenA.intersection(other: tokenB)

        let editDistanceA = intersection.tokenizedString.weightedMinimumEditDistance(other: tokenA.tokenizedString)
        let editDistanceB = intersection.tokenizedString.weightedMinimumEditDistance(other: tokenB.tokenizedString)

        return (editDistanceA + editDistanceB) / 2.0
    }

    private func weightedMinimumEditDistance(other: String) -> Double {
        let editDistance = minimumEditDistance(other: other)
        let maxDistance = max(count, other.count)

        guard maxDistance > 0, editDistance < maxDistance else {
            return 1.0
        }

        return Double(editDistance) / Double(maxDistance)
    }

    private func minimumEditDistance(other: String) -> Int {
        let minValue = 0
        let maxValue = Int.max

        if trimmingCharacters(in: .whitespaces).isEmpty || other.trimmingCharacters(in: .whitespaces).isEmpty {
            return maxValue
        }

        if self == other {
            return minValue
        }

        let m = count
        let n = other.count
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        for index in 1...m {
            matrix[index][0] = index
        }

        for index in 1...n {
            matrix[0][index] = index
        }

        for (i, selfChar) in enumerated() {
            for (j, otherChar) in other.enumerated() {
                if otherChar == selfChar {
                    matrix[i + 1][j + 1] = matrix[i][j]
                } else {
                    matrix[i + 1][j + 1] = Swift.min(matrix[i][j] + 1, matrix[i + 1][j] + 1, matrix[i][j + 1] + 1)
                }
            }
        }

        return matrix[m][n]
    }
}
