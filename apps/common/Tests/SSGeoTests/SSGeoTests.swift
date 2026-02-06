import Foundation
import Testing

@testable import SSGeo

#if canImport(CoreLocation)
import CoreLocation
#endif

struct SSGeoTests {

    @Test
    func coordinateValidation() {
        #expect(SSGeoCoordinate(latitude: 47.6205, longitude: -122.3493).isValid)
        #expect(!SSGeoCoordinate(latitude: 120.0, longitude: 0).isValid)
        #expect(!SSGeoCoordinate(latitude: 0, longitude: -200.0).isValid)
    }

    @Test
    func initialBearingIsNormalized() {
        let start = SSGeoCoordinate(latitude: 47.6205, longitude: -122.3493)
        let end = SSGeoCoordinate(latitude: 47.6062, longitude: -122.3321)

        let bearing = SSGeoMath.initialBearingDegrees(from: start, to: end)
        #expect((0.0 ..< 360.0).contains(bearing))
    }

    @Test
    func speedFromTimestampsUsesDistanceOverTime() {
        let startTime = Date(timeIntervalSince1970: 1_700_000_000)
        let endTime = startTime.addingTimeInterval(20.0)

        let start = SSGeoLocation(
            coordinate: SSGeoCoordinate(latitude: 47.6205, longitude: -122.3493),
            timestamp: startTime
        )
        let end = SSGeoLocation(
            coordinate: SSGeoCoordinate(latitude: 47.6210, longitude: -122.3493),
            timestamp: endTime
        )

        let speed = SSGeoMath.speedMetersPerSecond(from: start, to: end)
        #expect(speed != nil)

        if let speed {
            #expect(speed > 0)
        }
    }

    #if canImport(CoreLocation)
    @Test
    func distanceAccuracyComparedToCoreLocation() {
        var rng = LCRandom(seed: 0xC0FFEE)
        var maxRelativeError = 0.0
        var maxAbsoluteErrorUnder10km = 0.0

        for _ in 0 ..< 1_500 {
            let from = randomCoordinate(rng: &rng)
            let to = randomCoordinate(rng: &rng)

            let ours = SSGeoMath.distanceMeters(from: from, to: to)
            let expected = CLLocation(
                latitude: from.latitude,
                longitude: from.longitude
            ).distance(
                from: CLLocation(latitude: to.latitude, longitude: to.longitude)
            )

            let absError = abs(ours - expected)
            let relError = expected > 0 ? absError / expected : 0

            maxRelativeError = max(maxRelativeError, relError)
            if expected <= 10_000.0 {
                maxAbsoluteErrorUnder10km = max(maxAbsoluteErrorUnder10km, absError)
            }

            if expected > 1.0 {
                #expect(relError < 0.0075)
            } else {
                #expect(absError < 0.5)
            }
        }

        #expect(maxRelativeError < 0.0075)
        #expect(maxAbsoluteErrorUnder10km < 40.0)
    }

    @Test
    func distancePerformanceComparedToCoreLocation() {
        var rng = LCRandom(seed: 0xBADC0DE)
        let pairs: [(SSGeoCoordinate, SSGeoCoordinate)] = (0 ..< 30_000).map { _ in
            (randomCoordinate(rng: &rng), randomCoordinate(rng: &rng))
        }

        // Warm up and stabilize JIT/optimizer effects.
        _ = computeDistanceSumWithSSGeo(pairs: pairs)
        _ = computeDistanceSumWithCoreLocation(pairs: pairs)

        let (oursDuration, oursSum) = measure {
            computeDistanceSumWithSSGeo(pairs: pairs)
        }
        let (coreDuration, coreSum) = measure {
            computeDistanceSumWithCoreLocation(pairs: pairs)
        }

        let relError = abs(oursSum - coreSum) / coreSum
        #expect(relError < 0.01)

        let ratio = oursDuration / max(coreDuration, 0.000_001)
        #expect(ratio < 6.0)
    }

    private func computeDistanceSumWithSSGeo(pairs: [(SSGeoCoordinate, SSGeoCoordinate)]) -> Double {
        var sum = 0.0
        for pair in pairs {
            sum += SSGeoMath.distanceMeters(from: pair.0, to: pair.1)
        }
        return sum
    }

    private func computeDistanceSumWithCoreLocation(pairs: [(SSGeoCoordinate, SSGeoCoordinate)]) -> Double {
        var sum = 0.0
        for pair in pairs {
            let from = CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
            let to = CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude)
            sum += from.distance(from: to)
        }
        return sum
    }
    #endif

    private func randomCoordinate(rng: inout LCRandom) -> SSGeoCoordinate {
        let latitude = rng.next(in: -80.0 ... 80.0)
        let longitude = rng.next(in: -170.0 ... 170.0)
        return SSGeoCoordinate(latitude: latitude, longitude: longitude)
    }

    private func measure(_ block: () -> Double) -> (TimeInterval, Double) {
        let start = CFAbsoluteTimeGetCurrent()
        let result = block()
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        return (elapsed, result)
    }
}

private struct LCRandom {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = 6364136223846793005 &* state &+ 1
        return state
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        let value = Double(next() >> 11) / Double(1 << 53)
        return range.lowerBound + (range.upperBound - range.lowerBound) * value
    }
}
