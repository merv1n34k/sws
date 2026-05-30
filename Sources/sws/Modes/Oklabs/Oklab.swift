import Foundation

/// Oklab is a perceptually uniform color space — Euclidean distance
/// in Oklab approximates perceived color difference much better than
/// in sRGB or linear RGB. Used for k-means clustering so the produced
/// palette is visually meaningful instead of biased by green dominance.
///
/// References:
/// - https://bottosson.github.io/posts/oklab/
struct Oklab: Equatable {
    var L: Double
    var a: Double
    var b: Double

    static func fromSRGB(r: UInt8, g: UInt8, b: UInt8) -> Oklab {
        let rL = srgbToLinear(Double(r) / 255.0)
        let gL = srgbToLinear(Double(g) / 255.0)
        let bL = srgbToLinear(Double(b) / 255.0)
        return fromLinearRGB(r: rL, g: gL, b: bL)
    }

    static func fromLinearRGB(r: Double, g: Double, b: Double) -> Oklab {
        let l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
        let m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
        let s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

        let l_ = cbrt(l)
        let m_ = cbrt(m)
        let s_ = cbrt(s)

        return Oklab(
            L: 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
            a: 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
            b: 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
        )
    }

    /// Returns (r, g, b) tuple with components in [0, 255], clamped.
    func toSRGB() -> (r: UInt8, g: UInt8, b: UInt8) {
        let (rL, gL, bL) = toLinearRGB()
        let r = linearToSRGB(rL)
        let g = linearToSRGB(gL)
        let bb = linearToSRGB(bL)
        return (
            UInt8(max(0, min(255, round(r * 255)))),
            UInt8(max(0, min(255, round(g * 255)))),
            UInt8(max(0, min(255, round(bb * 255))))
        )
    }

    func toLinearRGB() -> (r: Double, g: Double, b: Double) {
        let l_ = L + 0.3963377774 * a + 0.2158037573 * b
        let m_ = L - 0.1055613458 * a - 0.0638541728 * b
        let s_ = L - 0.0894841775 * a - 1.2914855480 * b

        let l = l_ * l_ * l_
        let m = m_ * m_ * m_
        let s = s_ * s_ * s_

        return (
            r:  4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            g: -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            b: -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        )
    }

    func squaredDistance(to other: Oklab) -> Double {
        let dL = L - other.L
        let da = a - other.a
        let db = b - other.b
        return dL * dL + da * da + db * db
    }
}

private func srgbToLinear(_ c: Double) -> Double {
    c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
}

private func linearToSRGB(_ c: Double) -> Double {
    c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1.0 / 2.4) - 0.055
}
