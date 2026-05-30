import AppKit
import CoreGraphics

/// Reads pixel data out of a CGImage as color-managed sRGB values.
/// Delegates to NSBitmapImageRep + NSColor.usingColorSpace so AppKit
/// handles the source byte order, premultiplication, and color-space
/// matching — the hand-rolled CGContext path that lived here before
/// produced garbage values on at least some configurations.
enum PixelReader {
    /// Returns the first (top-left) pixel of `image` as sRGB bytes.
    static func firstPixel(of image: CGImage) -> (r: UInt8, g: UInt8, b: UInt8)? {
        return pixel(of: image, atX: 0, y: 0)
    }

    static func pixel(of image: CGImage, atX x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8)? {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let raw = rep.colorAt(x: x, y: y),
              let srgb = raw.usingColorSpace(.sRGB) else { return nil }
        return (
            UInt8(clamping: Int(round(srgb.redComponent * 255))),
            UInt8(clamping: Int(round(srgb.greenComponent * 255))),
            UInt8(clamping: Int(round(srgb.blueComponent * 255)))
        )
    }

    /// Returns the rendered image as sRGB RGBA bytes, one pixel at a time
    /// via NSBitmapImageRep. Slower than a single CGContext draw but
    /// reliable across all source formats — palette extraction only needs
    /// ≤10k samples so the cost is negligible.
    static func sRGBPixels(of image: CGImage) -> [(r: UInt8, g: UInt8, b: UInt8)] {
        let rep = NSBitmapImageRep(cgImage: image)
        var out: [(UInt8, UInt8, UInt8)] = []
        out.reserveCapacity(rep.pixelsWide * rep.pixelsHigh)
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                if let raw = rep.colorAt(x: x, y: y),
                   let srgb = raw.usingColorSpace(.sRGB) {
                    out.append((
                        UInt8(clamping: Int(round(srgb.redComponent * 255))),
                        UInt8(clamping: Int(round(srgb.greenComponent * 255))),
                        UInt8(clamping: Int(round(srgb.blueComponent * 255)))
                    ))
                }
            }
        }
        return out
    }
}
