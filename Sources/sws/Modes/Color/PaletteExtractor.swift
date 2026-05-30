import AppKit
import CoreGraphics

/// Extracts a palette of dominant colors from a CGImage by sampling
/// pixels, converting to Oklab, and running k-means.
///
/// `paletteSize` defaults to 8 — matches okolors' default. The input
/// is downsampled (uniform stride) to at most `maxSamples` pixels so
/// even a multi-megapixel region clusters in <100ms.
enum PaletteExtractor {
    static func extract(
        from image: CGImage,
        paletteSize k: Int = 8,
        maxSamples: Int = 10_000
    ) -> [NSColor] {
        let pixels = samplePixels(image: image, max: maxSamples)
        guard !pixels.isEmpty else { return [] }
        let oklab = pixels.map { Oklab.fromSRGB(r: $0.r, g: $0.g, b: $0.b) }
        let centroids = Kmeans.cluster(points: oklab, k: k)
        return centroids.map { c in
            let (r, g, b) = c.toSRGB()
            return NSColor(
                srgbRed: CGFloat(r) / 255,
                green: CGFloat(g) / 255,
                blue: CGFloat(b) / 255,
                alpha: 1
            )
        }
    }

    /// Samples up to `cap` pixels uniformly from the image. Returns
    /// raw 8-bit sRGB triples (color-managed via PixelReader).
    private static func samplePixels(image: CGImage, max cap: Int) -> [(r: UInt8, g: UInt8, b: UInt8)] {
        let pixels = PixelReader.sRGBPixels(of: image)
        guard !pixels.isEmpty else { return [] }
        let step = max(1, pixels.count / cap)
        var out: [(UInt8, UInt8, UInt8)] = []
        out.reserveCapacity(min(pixels.count, cap))
        var idx = 0
        while idx < pixels.count {
            out.append(pixels[idx])
            idx += step
        }
        return out
    }
}
