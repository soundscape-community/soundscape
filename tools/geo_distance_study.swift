import Foundation
import CoreLocation

// MARK: - Models

struct Coordinate {
    let latitude: Double
    let longitude: Double
}

struct Pair {
    let a: Coordinate
    let b: Coordinate
}

struct ErrorStats {
    private(set) var count: Int = 0
    private(set) var absErrorSum: Double = 0
    private(set) var sqErrorSum: Double = 0
    private(set) var maxAbsError: Double = 0

    mutating func add(_ diff: Double) {
        let absDiff = abs(diff)
        count += 1
        absErrorSum += absDiff
        sqErrorSum += absDiff * absDiff
        if absDiff > maxAbsError {
            maxAbsError = absDiff
        }
    }

    var mae: Double {
        guard count > 0 else { return 0 }
        return absErrorSum / Double(count)
    }

    var rmse: Double {
        guard count > 0 else { return 0 }
        return sqrt(sqErrorSum / Double(count))
    }
}

struct Outlier {
    let pair: Pair
    let core: Double
    let spherical: Double
    let vincenty: Double

    var coreMinusVincenty: Double { core - vincenty }
    var sphericalMinusVincenty: Double { spherical - vincenty }
}

// MARK: - Deterministic RNG

struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func nextDouble01() -> Double {
        let u = nextUInt64() >> 11
        return Double(u) / Double(1 << 53)
    }

    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * nextDouble01()
    }
}

// MARK: - Helpers

@inline(__always)
func deg2rad(_ degrees: Double) -> Double {
    degrees * .pi / 180.0
}

@inline(__always)
func rad2deg(_ radians: Double) -> Double {
    radians * 180.0 / .pi
}

func normalizeLongitude(_ lon: Double) -> Double {
    var result = lon
    while result > 180 { result -= 360 }
    while result < -180 { result += 360 }
    return result
}

func destination(from start: Coordinate, distanceMeters: Double, bearingDegrees: Double, radius: Double) -> Coordinate {
    let delta = distanceMeters / radius
    let theta = deg2rad(bearingDegrees)

    let phi1 = deg2rad(start.latitude)
    let lambda1 = deg2rad(start.longitude)

    let sinPhi2 = sin(phi1) * cos(delta) + cos(phi1) * sin(delta) * cos(theta)
    let phi2 = asin(sinPhi2)

    let y = sin(theta) * sin(delta) * cos(phi1)
    let x = cos(delta) - sin(phi1) * sinPhi2
    let lambda2 = lambda1 + atan2(y, x)

    return Coordinate(
        latitude: rad2deg(phi2),
        longitude: normalizeLongitude(rad2deg(lambda2))
    )
}

// MARK: - Distance Algorithms

func coreLocationDistance(_ a: Coordinate, _ b: Coordinate) -> Double {
    CLLocation(latitude: a.latitude, longitude: a.longitude)
        .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
}

func sphericalDistance(_ a: Coordinate, _ b: Coordinate, radius: Double = 6_371_000.0) -> Double {
    let phi1 = deg2rad(a.latitude)
    let phi2 = deg2rad(b.latitude)
    let dPhi = deg2rad(b.latitude - a.latitude)
    let dLambda = deg2rad(b.longitude - a.longitude)

    let sinDPhi = sin(dPhi / 2.0)
    let sinDLambda = sin(dLambda / 2.0)

    let h = sinDPhi * sinDPhi + cos(phi1) * cos(phi2) * sinDLambda * sinDLambda
    let c = 2.0 * atan2(sqrt(h), sqrt(max(0.0, 1.0 - h)))
    return radius * c
}

// Vincenty inverse solution on WGS84 ellipsoid.
func vincentyDistanceWGS84(_ a: Coordinate, _ b: Coordinate, maxIterations: Int = 200, tolerance: Double = 1e-12) -> Double? {
    let semimajor = 6_378_137.0
    let flattening = 1.0 / 298.257_223_563
    let semiminor = (1.0 - flattening) * semimajor

    let phi1 = deg2rad(a.latitude)
    let phi2 = deg2rad(b.latitude)
    let l = deg2rad(b.longitude - a.longitude)

    let tanU1 = (1.0 - flattening) * tan(phi1)
    let tanU2 = (1.0 - flattening) * tan(phi2)
    let u1 = atan(tanU1)
    let u2 = atan(tanU2)

    let sinU1 = sin(u1)
    let cosU1 = cos(u1)
    let sinU2 = sin(u2)
    let cosU2 = cos(u2)

    var lambda = l
    var lambdaPrev = 0.0

    var sinSigma = 0.0
    var cosSigma = 0.0
    var sigma = 0.0
    var sinAlpha = 0.0
    var cosSqAlpha = 0.0
    var cos2SigmaM = 0.0

    for _ in 0..<maxIterations {
        let sinLambda = sin(lambda)
        let cosLambda = cos(lambda)

        let term1 = cosU2 * sinLambda
        let term2 = cosU1 * sinU2 - sinU1 * cosU2 * cosLambda
        let sum = term1 * term1 + term2 * term2
        sinSigma = sqrt(sum)

        // coincident points
        if sinSigma == 0 {
            return 0
        }

        cosSigma = sinU1 * sinU2 + cosU1 * cosU2 * cosLambda
        sigma = atan2(sinSigma, cosSigma)

        sinAlpha = cosU1 * cosU2 * sinLambda / sinSigma
        cosSqAlpha = 1.0 - sinAlpha * sinAlpha

        if cosSqAlpha != 0 {
            cos2SigmaM = cosSigma - 2.0 * sinU1 * sinU2 / cosSqAlpha
        } else {
            cos2SigmaM = 0 // equatorial line
        }

        let c = flattening / 16.0 * cosSqAlpha * (4.0 + flattening * (4.0 - 3.0 * cosSqAlpha))

        lambdaPrev = lambda
        lambda = l + (1.0 - c) * flattening * sinAlpha * (
            sigma + c * sinSigma * (
                cos2SigmaM + c * cosSigma * (-1.0 + 2.0 * cos2SigmaM * cos2SigmaM)
            )
        )

        if abs(lambda - lambdaPrev) <= tolerance {
            let uSq = cosSqAlpha * (semimajor * semimajor - semiminor * semiminor) / (semiminor * semiminor)
            let aCoeff = 1.0 + uSq / 16_384.0 * (
                4_096.0 + uSq * (-768.0 + uSq * (320.0 - 175.0 * uSq))
            )
            let bCoeff = uSq / 1_024.0 * (
                256.0 + uSq * (-128.0 + uSq * (74.0 - 47.0 * uSq))
            )

            let deltaSigma = bCoeff * sinSigma * (
                cos2SigmaM + bCoeff / 4.0 * (
                    cosSigma * (-1.0 + 2.0 * cos2SigmaM * cos2SigmaM)
                    - bCoeff / 6.0 * cos2SigmaM
                    * (-3.0 + 4.0 * sinSigma * sinSigma)
                    * (-3.0 + 4.0 * cos2SigmaM * cos2SigmaM)
                )
            )

            return semiminor * aCoeff * (sigma - deltaSigma)
        }
    }

    return nil
}

// MARK: - Dataset Generation

func randomCoordinate(rng: inout SplitMix64) -> Coordinate {
    Coordinate(
        latitude: rng.nextDouble(in: -80.0...80.0),
        longitude: rng.nextDouble(in: -180.0...180.0)
    )
}

func makeShortPairs(count: Int, rng: inout SplitMix64) -> [Pair] {
    var out: [Pair] = []
    out.reserveCapacity(count)

    for _ in 0..<count {
        let start = randomCoordinate(rng: &rng)
        let distance = rng.nextDouble(in: 1.0...5_000.0)
        let bearing = rng.nextDouble(in: 0.0...360.0)
        let end = destination(from: start, distanceMeters: distance, bearingDegrees: bearing, radius: 6_371_000.0)
        out.append(Pair(a: start, b: end))
    }

    return out
}

func makeLongPairs(count: Int, rng: inout SplitMix64) -> [Pair] {
    var out: [Pair] = []
    out.reserveCapacity(count)

    while out.count < count {
        let a = randomCoordinate(rng: &rng)
        let b = randomCoordinate(rng: &rng)
        if a.latitude == b.latitude && a.longitude == b.longitude {
            continue
        }
        out.append(Pair(a: a, b: b))
    }

    return out
}

// MARK: - Analysis

func analyze(name: String, pairs: [Pair]) {
    var coreVsVin = ErrorStats()
    var sphericalVsVin = ErrorStats()
    var coreVsSpherical = ErrorStats()

    var vincentyFailures = 0
    var coreCloserToVincenty = 0
    var sphericalCloserToVincenty = 0
    var equalCloseness = 0

    var outliers: [Outlier] = []
    outliers.reserveCapacity(pairs.count)

    for p in pairs {
        guard let vin = vincentyDistanceWGS84(p.a, p.b) else {
            vincentyFailures += 1
            continue
        }

        let core = coreLocationDistance(p.a, p.b)
        let sph = sphericalDistance(p.a, p.b)

        let coreDiff = core - vin
        let sphDiff = sph - vin

        coreVsVin.add(coreDiff)
        sphericalVsVin.add(sphDiff)
        coreVsSpherical.add(core - sph)

        let coreAbs = abs(coreDiff)
        let sphAbs = abs(sphDiff)

        if coreAbs < sphAbs {
            coreCloserToVincenty += 1
        } else if sphAbs < coreAbs {
            sphericalCloserToVincenty += 1
        } else {
            equalCloseness += 1
        }

        outliers.append(Outlier(pair: p, core: core, spherical: sph, vincenty: vin))
    }

    outliers.sort { abs($0.coreMinusVincenty) > abs($1.coreMinusVincenty) }

    let coreMae = String(format: "%.4f", coreVsVin.mae)
    let coreRmse = String(format: "%.4f", coreVsVin.rmse)
    let coreMax = String(format: "%.4f", coreVsVin.maxAbsError)

    let sphMae = String(format: "%.4f", sphericalVsVin.mae)
    let sphRmse = String(format: "%.4f", sphericalVsVin.rmse)
    let sphMax = String(format: "%.4f", sphericalVsVin.maxAbsError)

    let coreVsSphMae = String(format: "%.4f", coreVsSpherical.mae)
    let coreVsSphRmse = String(format: "%.4f", coreVsSpherical.rmse)
    let coreVsSphMax = String(format: "%.4f", coreVsSpherical.maxAbsError)

    print("\n=== \(name) ===")
    print("Pairs: \(pairs.count), Vincenty failures: \(vincentyFailures)")
    print("CoreLocation vs Vincenty (meters): mae=\(coreMae) rmse=\(coreRmse) max=\(coreMax)")
    print("Spherical(6371000) vs Vincenty (meters): mae=\(sphMae) rmse=\(sphRmse) max=\(sphMax)")
    print("CoreLocation vs Spherical (meters): mae=\(coreVsSphMae) rmse=\(coreVsSphRmse) max=\(coreVsSphMax)")

    let comparable = coreCloserToVincenty + sphericalCloserToVincenty + equalCloseness
    if comparable > 0 {
        print("Closer-to-Vincenty counts: CoreLocation=\(coreCloserToVincenty), Spherical=\(sphericalCloserToVincenty), Equal=\(equalCloseness)")
        let coreRate = String(format: "%.2f", 100.0 * Double(coreCloserToVincenty) / Double(comparable))
        let sphRate = String(format: "%.2f", 100.0 * Double(sphericalCloserToVincenty) / Double(comparable))
        print("Closer-to-Vincenty rates: CoreLocation=\(coreRate)% Spherical=\(sphRate)%")
    }

    print("Top 5 CoreLocation-vs-Vincenty absolute deltas (meters):")
    for (idx, o) in outliers.prefix(5).enumerated() {
        print(
            String(
                format: "  %d) |core-vin|=%.3f |sph-vin|=%.3f  core=%.3f sph=%.3f vin=%.3f  a=(%.5f,%.5f) b=(%.5f,%.5f)",
                idx + 1,
                abs(o.coreMinusVincenty),
                abs(o.sphericalMinusVincenty),
                o.core,
                o.spherical,
                o.vincenty,
                o.pair.a.latitude,
                o.pair.a.longitude,
                o.pair.b.latitude,
                o.pair.b.longitude
            )
        )
    }
}

// MARK: - Benchmark

func benchmark(name: String, repeats: Int, _ block: () -> Double) {
    let start = DispatchTime.now().uptimeNanoseconds
    var checksum = 0.0
    for _ in 0..<repeats {
        checksum += block()
    }
    let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000.0
    print(String(format: "%@: %.4fs total (%.6f ms/op batch), checksum=%.3f", name, elapsed, (elapsed * 1000.0) / Double(repeats), checksum))
}

func benchmarkSet(name: String, pairs: [Pair], repeats: Int) {
    print("\n=== Benchmark \(name) ===")

    let vincentyComparable = pairs.filter { vincentyDistanceWGS84($0.a, $0.b) != nil }

    benchmark(name: "CoreLocation", repeats: repeats) {
        var sum = 0.0
        for p in pairs {
            sum += coreLocationDistance(p.a, p.b)
        }
        return sum
    }

    benchmark(name: "Spherical(6371000)", repeats: repeats) {
        var sum = 0.0
        for p in pairs {
            sum += sphericalDistance(p.a, p.b)
        }
        return sum
    }

    benchmark(name: "Vincenty WGS84", repeats: repeats) {
        var sum = 0.0
        for p in vincentyComparable {
            sum += vincentyDistanceWGS84(p.a, p.b) ?? 0
        }
        return sum
    }

    print("Vincenty comparable pairs used in benchmark: \(vincentyComparable.count)/\(pairs.count)")
}

// MARK: - Entry

let shortCount = 20_000
let longCount = 20_000
let benchmarkRepeats = 10

var rng = SplitMix64(seed: 0xC0FFEE1234)
let shortPairs = makeShortPairs(count: shortCount, rng: &rng)
let longPairs = makeLongPairs(count: longCount, rng: &rng)

print("Geo Distance Comparison Study")
print("Short pairs: \(shortCount), Long pairs: \(longCount)")
print("Algorithms: CoreLocation, Spherical Haversine (R=6371000), Vincenty WGS84")

analyze(name: "Short-range (1m to 5km)", pairs: shortPairs)
analyze(name: "Long-range (global random)", pairs: longPairs)

benchmarkSet(name: "Short-range", pairs: shortPairs, repeats: benchmarkRepeats)
benchmarkSet(name: "Long-range", pairs: longPairs, repeats: benchmarkRepeats)
