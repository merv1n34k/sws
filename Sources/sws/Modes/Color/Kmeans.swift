import Foundation

/// Minimal k-means clustering for Oklab points. Uses k-means++
/// initialization (each subsequent centroid is sampled proportional
/// to squared distance from the nearest existing centroid) and
/// terminates on either convergence (no point changes cluster) or
/// `maxIterations`.
///
/// This is the "minimal okolors" core: feed it pixel colors,
/// receive K dominant colors back in Oklab space. The caller
/// converts back to sRGB for display.
enum Kmeans {
    /// Returns up to `k` cluster centroids sorted by population
    /// descending (most-common color first). May return fewer
    /// centroids than `k` if the input has fewer unique colors.
    static func cluster(
        points: [Oklab],
        k: Int,
        maxIterations: Int = 32,
        seed: UInt64 = 0xC0_DE_C0_DE
    ) -> [Oklab] {
        guard !points.isEmpty else { return [] }
        let k = min(k, points.count)
        guard k > 0 else { return [] }

        var rng = SplitMix64(seed: seed)
        var centroids = initCentroidsPlusPlus(points: points, k: k, rng: &rng)
        var assignment = [Int](repeating: -1, count: points.count)

        for _ in 0..<maxIterations {
            var changed = false
            for (i, p) in points.enumerated() {
                let nearest = nearestCentroid(point: p, centroids: centroids)
                if assignment[i] != nearest {
                    assignment[i] = nearest
                    changed = true
                }
            }
            if !changed { break }

            var sums = Array(repeating: (L: 0.0, a: 0.0, b: 0.0, n: 0), count: k)
            for (i, p) in points.enumerated() {
                let c = assignment[i]
                sums[c].L += p.L
                sums[c].a += p.a
                sums[c].b += p.b
                sums[c].n += 1
            }
            for j in 0..<k {
                if sums[j].n > 0 {
                    let n = Double(sums[j].n)
                    centroids[j] = Oklab(L: sums[j].L / n, a: sums[j].a / n, b: sums[j].b / n)
                }
            }
        }

        // Sort by cluster population (descending) so the most prevalent
        // color is first in the palette.
        var counts = [Int](repeating: 0, count: k)
        for c in assignment where c >= 0 { counts[c] += 1 }
        let indexed = (0..<k).map { ($0, counts[$0]) }.sorted { $0.1 > $1.1 }
        return indexed.compactMap { idx, count in
            count > 0 ? centroids[idx] : nil
        }
    }

    private static func nearestCentroid(point: Oklab, centroids: [Oklab]) -> Int {
        var best = 0
        var bestDist = Double.infinity
        for (i, c) in centroids.enumerated() {
            let d = point.squaredDistance(to: c)
            if d < bestDist {
                bestDist = d
                best = i
            }
        }
        return best
    }

    private static func initCentroidsPlusPlus(
        points: [Oklab],
        k: Int,
        rng: inout SplitMix64
    ) -> [Oklab] {
        var centroids: [Oklab] = []
        centroids.reserveCapacity(k)

        let first = Int(rng.next() % UInt64(points.count))
        centroids.append(points[first])

        var dists = points.map { $0.squaredDistance(to: centroids[0]) }

        while centroids.count < k {
            let total = dists.reduce(0, +)
            if total == 0 { break }
            let target = (Double(rng.next() % 1_000_000) / 1_000_000.0) * total
            var cumulative = 0.0
            var pick = points.count - 1
            for (i, d) in dists.enumerated() {
                cumulative += d
                if cumulative >= target {
                    pick = i
                    break
                }
            }
            centroids.append(points[pick])
            for i in 0..<points.count {
                let d = points[i].squaredDistance(to: centroids.last!)
                if d < dists[i] { dists[i] = d }
            }
        }
        return centroids
    }
}

/// Fast deterministic RNG. We don't need crypto randomness, and
/// determinism (via fixed seed) makes the k-means result repeatable
/// for the same input — useful for tests and for the user to get
/// the same palette twice from the same screenshot.
struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
