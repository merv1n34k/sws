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
    /// raw 8-bit RGB triples.
    private static func samplePixels(image: CGImage, max cap: Int) -> [(r: UInt8, g: UInt8, b: UInt8)] {
        let width = image.width
        let height = image.height
        let total = width * height
        guard total > 0 else { return [] }

        // Rendering into a known-format context lets us read pixels
        // without worrying about the source's byte order/alpha.
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var data = [UInt8](repeating: 0, count: bytesPerRow * height)
        let bitmapInfo: UInt32 =
            CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue

        guard let ctx = data.withUnsafeMutableBytes({ ptr -> CGContext? in
            CGContext(
                data: ptr.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        }) else { return [] }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let step = max(1, total / cap)
        var out: [(UInt8, UInt8, UInt8)] = []
        out.reserveCapacity(min(total, cap))
        var idx = 0
        while idx < total {
            let off = idx * 4
            out.append((data[off], data[off + 1], data[off + 2]))
            idx += step
        }
        return out
    }
}
