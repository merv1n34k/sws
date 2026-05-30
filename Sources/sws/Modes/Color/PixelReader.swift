import CoreGraphics

/// Reads RGB bytes from CGImages by re-rendering into a known sRGB
/// context. Going through an explicit sRGB context performs the color
/// space conversion CG knows about — without it, captures from a P3
/// display would come back in the display's space and we'd
/// misinterpret the bytes as sRGB.
///
/// The output byte order is always [R, G, B, A], premultipliedLast.
enum PixelReader {
    /// Returns the first pixel of the image as sRGB bytes.
    static func firstPixel(of image: CGImage) -> (r: UInt8, g: UInt8, b: UInt8)? {
        guard let bytes = render(image: image, width: 1, height: 1) else { return nil }
        return (bytes[0], bytes[1], bytes[2])
    }

    /// Renders the image at its native size into an sRGB RGBA buffer
    /// and returns the raw bytes. Caller knows the dimensions.
    static func rgbaBytes(of image: CGImage) -> [UInt8]? {
        return render(image: image, width: image.width, height: image.height)
    }

    private static func render(image: CGImage, width: Int, height: Int) -> [UInt8]? {
        guard width > 0, height > 0 else { return nil }
        let bytesPerRow = width * 4
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var data = [UInt8](repeating: 0, count: bytesPerRow * height)
        let bitmapInfo: UInt32 =
            CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue

        let ok = data.withUnsafeMutableBytes { ptr -> Bool in
            guard let ctx = CGContext(
                data: ptr.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: space,
                bitmapInfo: bitmapInfo
            ) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return ok ? data : nil
    }
}
