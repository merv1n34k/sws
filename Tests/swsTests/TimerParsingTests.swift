import Testing
import Foundation
@testable import sws

@Suite("Duration parsing")
struct DurationParserTests {
    @Test
    func bareNumberIsSeconds() {
        #expect(DurationParser.parse("90") == 90)
        #expect(DurationParser.parse("5") == 5)
        #expect(DurationParser.parse("0.5") == 0.5)
    }

    @Test
    func suffixForms() {
        #expect(DurationParser.parse("30s") == 30)
        #expect(DurationParser.parse("5m") == 300)
        #expect(DurationParser.parse("1h") == 3600)
        #expect(DurationParser.parse("1h30m") == TimeInterval(3600 + 30 * 60))
        #expect(DurationParser.parse("2h45m15s") == TimeInterval(2 * 3600 + 45 * 60 + 15))
    }

    @Test
    func suffixIsCaseInsensitive() {
        #expect(DurationParser.parse("1H30M") == TimeInterval(3600 + 30 * 60))
    }

    @Test
    func colonForms() {
        #expect(DurationParser.parse("1:30") == 90)              // M:S
        #expect(DurationParser.parse("01:30:00") == TimeInterval(90 * 60))   // H:M:S
        #expect(DurationParser.parse("2:00:00") == 7200)
    }

    @Test
    func rejectsInvalid() {
        #expect(DurationParser.parse("") == nil)
        #expect(DurationParser.parse("abc") == nil)
        #expect(DurationParser.parse("0") == nil)              // non-positive
        #expect(DurationParser.parse("-5") == nil)
        #expect(DurationParser.parse("1h30") == nil)           // trailing unitless
        #expect(DurationParser.parse("1:2:3:4") == nil)        // too many parts
    }

    @Test
    func formatShortAndLong() {
        #expect(DurationParser.format(90) == "01:30")
        #expect(DurationParser.format(3661) == "1:01:01")
        #expect(DurationParser.format(0) == "00:00")
    }

    @Test
    func formatPreciseShowsCentiseconds() {
        #expect(DurationParser.formatPrecise(1.23) == "00:01.23")
        #expect(DurationParser.formatPrecise(65.5) == "01:05.50")
    }
}
