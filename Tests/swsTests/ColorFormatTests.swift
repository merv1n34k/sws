import Testing
import AppKit
@testable import sws

@Suite("Color format conversion")
struct ColorFormatTests {
    private func srgb(_ r: Double, _ g: Double, _ b: Double) -> NSColor {
        NSColor(srgbRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1)
    }

    @Test
    func hexPrimaryColors() {
        #expect(ColorFormat.hex(srgb(1, 0, 0)) == "#FF0000")
        #expect(ColorFormat.hex(srgb(0, 1, 0)) == "#00FF00")
        #expect(ColorFormat.hex(srgb(0, 0, 1)) == "#0000FF")
        #expect(ColorFormat.hex(srgb(0, 0, 0)) == "#000000")
        #expect(ColorFormat.hex(srgb(1, 1, 1)) == "#FFFFFF")
    }

    @Test
    func rgbFormat() {
        #expect(ColorFormat.rgb(srgb(1, 0.5, 0)) == "rgb(255, 128, 0)")
    }

    @Test
    func hslPureRed() {
        let parts = ColorFormat.hsl(srgb(1, 0, 0))
        #expect(parts == "hsl(0, 100%, 50%)")
    }

    @Test
    func hslWhiteIsZeroSaturationFullLight() {
        #expect(ColorFormat.hsl(srgb(1, 1, 1)) == "hsl(0, 0%, 100%)")
    }

    @Test
    func hslBlackIsZeroLight() {
        #expect(ColorFormat.hsl(srgb(0, 0, 0)) == "hsl(0, 0%, 0%)")
    }

    @Test
    func hsbPureRed() {
        #expect(ColorFormat.hsb(srgb(1, 0, 0)) == "hsb(0, 100%, 100%)")
    }

    @Test
    func hsbGray() {
        // 50% gray: H undefined (rendered 0), S=0, V=50%
        #expect(ColorFormat.hsb(srgb(0.5, 0.5, 0.5)) == "hsb(0, 0%, 50%)")
    }
}
