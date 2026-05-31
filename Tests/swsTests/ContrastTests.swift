import Testing
import AppKit
@testable import sws

@Suite("Contrast")
struct ContrastTests {
    @Test
    func whiteOnBlackIs21to1() {
        let r = ContrastSection.contrastRatio(.white, .black)
        #expect(abs(r - 21.0) < 0.01)
    }

    @Test
    func sameColorIs1to1() {
        let c = NSColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        let r = ContrastSection.contrastRatio(c, c)
        #expect(abs(r - 1.0) < 0.01)
    }

    @Test
    func verdictBoundaries() {
        #expect(ContrastSection.verdict(ratio: 4.5).contains("AA ✓"))
        #expect(ContrastSection.verdict(ratio: 4.4).contains("AA ✗"))
        #expect(ContrastSection.verdict(ratio: 7.0).contains("AAA ✓"))
        #expect(ContrastSection.verdict(ratio: 3.0).contains("AA-L ✓"))
        #expect(ContrastSection.verdict(ratio: 2.99).contains("AA-L ✗"))
    }
}
