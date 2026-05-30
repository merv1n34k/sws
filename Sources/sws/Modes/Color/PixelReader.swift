import AppKit
import CoreGraphics

/// Reads pixel bytes out of a CGImage by interpreting its actual
/// bitmap layout (alpha position + byte order). Returns RGB triples
/// in the image's *native* color space — for screen captures that's
/// the display's profile, which is what DigitalColorMeter shows in
/// its default "Display native values" mode.
///
/// We deliberately don't run the bytes through ColorSync. The
/// previous attempt to convert via NSBitmapImageRep / CGContext
/// produced very wrong values when the source CGImage had no
/// well-known color-space name (custom display ICC profile);
/// reading the bytes raw and matching DCM is the most predictable
/// behavior.
enum PixelReader {
    static func firstPixel(of image: CGImage) -> (r: UInt8, g: UInt8, b: UInt8)? {
        return pixel(of: image, atX: 0, y: 0)
    }

    static func pixel(of image: CGImage, atX x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8)? {
        guard let provider = image.dataProvider,
              let data = provider.data,
              let bytes = CFDataGetBytePtr(data) else {
            print("SWS pixel: no data provider")
            return nil
        }

        let width = image.width
        let height = image.height
        let bytesPerRow = image.bytesPerRow
        let bitsPerPixel = image.bitsPerPixel
        guard bitsPerPixel == 32 else {
            print("SWS pixel: unsupported bitsPerPixel=\(bitsPerPixel)")
            return nil
        }
        guard x >= 0, x < width, y >= 0, y < height else { return nil }

        let info = image.bitmapInfo
        let alphaInfo = CGImageAlphaInfo(rawValue: info.rawValue & CGBitmapInfo.alphaInfoMask.rawValue)!
        let isLittle = info.contains(.byteOrder32Little)

        let off = y * bytesPerRow + x * 4
        // Bitmap encoding describes the logical pixel as a 32-bit
        // word; byte order tells you how that word is laid out in
        // memory. Match the four common combinations explicitly.
        let r: UInt8
        let g: UInt8
        let b: UInt8
        switch (alphaInfo, isLittle) {
        case (.premultipliedLast, false), (.last, false), (.noneSkipLast, false):
            // logical RGBA, big-endian → memory R G B A
            r = bytes[off]; g = bytes[off + 1]; b = bytes[off + 2]
        case (.premultipliedLast, true), (.last, true), (.noneSkipLast, true):
            // logical RGBA, little-endian → memory A B G R
            b = bytes[off + 1]; g = bytes[off + 2]; r = bytes[off + 3]
        case (.premultipliedFirst, false), (.first, false), (.noneSkipFirst, false):
            // logical ARGB, big-endian → memory A R G B
            r = bytes[off + 1]; g = bytes[off + 2]; b = bytes[off + 3]
        case (.premultipliedFirst, true), (.first, true), (.noneSkipFirst, true):
            // logical ARGB, little-endian → memory B G R A
            b = bytes[off]; g = bytes[off + 1]; r = bytes[off + 2]
        default:
            print("SWS pixel: unhandled alphaInfo=\(alphaInfo.rawValue) little=\(isLittle)")
            return nil
        }
        return (r, g, b)
    }

    /// Returns every pixel of the image as native-space RGB triples.
    /// Used by PaletteExtractor; for small samples the per-pixel
    /// branching here is fine.
    static func sRGBPixels(of image: CGImage) -> [(r: UInt8, g: UInt8, b: UInt8)] {
        // Name kept for API stability; the values are in the image's
        // native space, just like firstPixel.
        guard let provider = image.dataProvider,
              let data = provider.data,
              let bytes = CFDataGetBytePtr(data),
              image.bitsPerPixel == 32 else { return [] }

        let width = image.width
        let height = image.height
        let bytesPerRow = image.bytesPerRow
        let info = image.bitmapInfo
        let alphaInfo = CGImageAlphaInfo(rawValue: info.rawValue & CGBitmapInfo.alphaInfoMask.rawValue)!
        let isLittle = info.contains(.byteOrder32Little)

        var out: [(UInt8, UInt8, UInt8)] = []
        out.reserveCapacity(width * height)

        for y in 0..<height {
            for x in 0..<width {
                let off = y * bytesPerRow + x * 4
                let r: UInt8, g: UInt8, b: UInt8
                switch (alphaInfo, isLittle) {
                case (.premultipliedLast, false), (.last, false), (.noneSkipLast, false):
                    r = bytes[off]; g = bytes[off + 1]; b = bytes[off + 2]
                case (.premultipliedLast, true), (.last, true), (.noneSkipLast, true):
                    b = bytes[off + 1]; g = bytes[off + 2]; r = bytes[off + 3]
                case (.premultipliedFirst, false), (.first, false), (.noneSkipFirst, false):
                    r = bytes[off + 1]; g = bytes[off + 2]; b = bytes[off + 3]
                case (.premultipliedFirst, true), (.first, true), (.noneSkipFirst, true):
                    b = bytes[off]; g = bytes[off + 1]; r = bytes[off + 2]
                default:
                    continue
                }
                out.append((r, g, b))
            }
        }
        return out
    }
}
