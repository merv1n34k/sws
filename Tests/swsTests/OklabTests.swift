import Testing
import Foundation
@testable import sws

@Suite("Oklab")
struct OklabTests {
    @Test
    func sRGBPrimariesRoundTrip() {
        let cases: [(UInt8, UInt8, UInt8)] = [
            (0, 0, 0),
            (255, 255, 255),
            (255, 0, 0),
            (0, 255, 0),
            (0, 0, 255),
            (128, 64, 200),
        ]
        for (r, g, b) in cases {
            let lab = Oklab.fromSRGB(r: r, g: g, b: b)
            let back = lab.toSRGB()
            // Allow ±1 due to round-trip rounding through linear+Oklab
            #expect(Int(back.r) >= Int(r) - 1 && Int(back.r) <= Int(r) + 1, "r mismatch for \(r),\(g),\(b)")
            #expect(Int(back.g) >= Int(g) - 1 && Int(back.g) <= Int(g) + 1, "g mismatch for \(r),\(g),\(b)")
            #expect(Int(back.b) >= Int(b) - 1 && Int(back.b) <= Int(b) + 1, "b mismatch for \(r),\(g),\(b)")
        }
    }

    @Test
    func whiteHasLightnessOne() {
        let white = Oklab.fromSRGB(r: 255, g: 255, b: 255)
        // L should be ~1.0 for sRGB white
        #expect(white.L > 0.99)
        #expect(abs(white.a) < 0.01)
        #expect(abs(white.b) < 0.01)
    }

    @Test
    func blackHasLightnessZero() {
        let black = Oklab.fromSRGB(r: 0, g: 0, b: 0)
        #expect(black.L < 0.01)
    }
}

@Suite("Kmeans")
struct KmeansTests {
    @Test
    func twoClustersSeparate() {
        // 5 red-ish + 5 blue-ish points; k=2 should split them.
        let reds = (0..<5).map { _ in
            Oklab.fromSRGB(r: UInt8(200 + Int.random(in: 0...30)), g: 20, b: 20)
        }
        let blues = (0..<5).map { _ in
            Oklab.fromSRGB(r: 20, g: 20, b: UInt8(200 + Int.random(in: 0...30)))
        }
        let centroids = Kmeans.cluster(points: reds + blues, k: 2)
        #expect(centroids.count == 2)
        // One centroid should be redder than blue, the other bluer than red.
        let c0sRGB = centroids[0].toSRGB()
        let c1sRGB = centroids[1].toSRGB()
        let c0red = c0sRGB.r > c0sRGB.b
        let c1red = c1sRGB.r > c1sRGB.b
        #expect(c0red != c1red, "clusters should split into one redder + one bluer")
    }

    @Test
    func singleColorReturnsThatColor() {
        let same = Array(repeating: Oklab.fromSRGB(r: 100, g: 150, b: 200), count: 20)
        let centroids = Kmeans.cluster(points: same, k: 4)
        #expect(centroids.count == 1)  // duplicates collapse
    }

    @Test
    func emptyInputReturnsEmpty() {
        #expect(Kmeans.cluster(points: [], k: 5).isEmpty)
    }

    @Test
    func isDeterministicGivenSeed() {
        var pts: [Oklab] = []
        for i in 0..<50 {
            let r = UInt8((i * 5) % 256)
            let g = UInt8((i * 7) % 256)
            let b = UInt8((i * 11) % 256)
            pts.append(Oklab.fromSRGB(r: r, g: g, b: b))
        }
        let a = Kmeans.cluster(points: pts, k: 5, seed: 42)
        let b = Kmeans.cluster(points: pts, k: 5, seed: 42)
        #expect(a.count == b.count)
        for i in 0..<a.count {
            #expect(a[i] == b[i])
        }
    }
}
