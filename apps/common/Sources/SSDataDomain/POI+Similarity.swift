// Copyright (c) Soundscape Community Contributers.

import Foundation

public extension POI {
    func match<T: POI>(others: [T], threshold: Double = 1.0) -> T? {
        let weightedMatches = others.compactMap { entity -> (entity: T, metric: Double)? in
            guard isCategoryMatch(other: entity) else {
                return nil
            }

            let stringMetric = computeString(other: entity)
            let spatialMetric = computeSpatial(other: entity)
            let spatialWeight = max(stringMetric, 0.0)
            let weighted = stringMetric + (spatialMetric * spatialWeight)

            guard weighted > threshold else {
                return nil
            }

            return (entity, weighted)
        }

        return weightedMatches.max(by: { $0.metric < $1.metric })?.entity
    }

    private func isCategoryMatch(other: any POI) -> Bool {
        if let filterableA = self as? any Typeable, let filterableB = other as? any Typeable {
            let isTransitStopA = filterableA.isOfType(.transitStop)
            let isTransitStopB = filterableB.isOfType(.transitStop)

            return isTransitStopA == isTransitStopB
        }

        return true
    }

    private func computeSpatial(other: any POI, threshold: Double = 250.0) -> Double {
        let centerA = centroidSSGeoLocation
        let centerB = other.centroidSSGeoLocation
        let distA = distanceToClosestLocation(from: centerB, useEntranceIfAvailable: false)
        let distB = other.distanceToClosestLocation(from: centerA, useEntranceIfAvailable: false)

        return 1 - (min(distA, distB) / threshold)
    }

    private func computeString(other: any POI, threshold: Double = 0.8) -> Double {
        let setMetric = name.tokenSet(other: other.name)
        let sortMetric = name.tokenSort(other: other.name)

        return 1 - (min(setMetric, sortMetric) / threshold)
    }
}
