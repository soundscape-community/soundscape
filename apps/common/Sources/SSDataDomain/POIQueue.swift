// Copyright (c) Soundscape Community Contributers.

import Foundation

public final class POIQueue {
    public private(set) var pois: [any POI] = []

    private let maxItems: Int
    private let sort: any SortPredicate
    private let filter: (any FilterPredicate)?

    public init(maxItems: Int, sort: any SortPredicate, filter: (any FilterPredicate)?) {
        guard maxItems > 0 else {
            fatalError("maxItems must be greater than zero")
        }

        self.maxItems = maxItems
        self.sort = sort
        self.filter = filter
    }

    @inline(__always)
    private func findInsertionIndex(poi: any POI) -> Int {
        var left = 0
        var right = pois.count - 1

        while left <= right {
            let mid = (left + right) / 2

            if sort.areInIncreasingOrder(poi, pois[mid]) == false {
                left = mid + 1
            } else {
                right = mid - 1
            }
        }

        return left
    }

    public func insert(_ poi: any POI) {
        if let filter = filter {
            guard filter.isIncluded(poi) else {
                return
            }
        }

        guard pois.count != maxItems || sort.areInIncreasingOrder(poi, pois[maxItems - 1]) else {
            return
        }

        if maxItems == 1 {
            pois.insert(poi, at: 0)

            if pois.count > maxItems {
                pois.removeLast()
            }

            return
        }

        let insertionIndex = findInsertionIndex(poi: poi)
        guard insertionIndex >= 0 else {
            return
        }

        pois.insert(poi, at: insertionIndex)

        if pois.count > maxItems {
            pois.removeLast()
        }
    }

    public func insert(_ pois: [any POI]) {
        for poi in pois {
            insert(poi)
        }
    }
}
