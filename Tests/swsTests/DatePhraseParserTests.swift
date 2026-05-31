import Testing
import Foundation
@testable import sws

@Suite("DatePhraseParser")
struct DatePhraseParserTests {
    // Fixed reference so tests are deterministic.
    // 2024-03-15 12:00:00 UTC, which is a FRIDAY.
    private static let referenceNow: Date = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c.date(from: DateComponents(year: 2024, month: 3, day: 15, hour: 12, minute: 0))!
    }()

    private static var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()

    @Test
    func inNHoursFromNow() {
        let d = DatePhraseParser.parse("20 hours from now", now: Self.referenceNow, calendar: Self.calendar)
        #expect(d != nil)
        if let d = d {
            let diff = d.timeIntervalSince(Self.referenceNow)
            #expect(abs(diff - 20 * 3600) < 1)
        }
    }

    @Test
    func inHoursPrefix() {
        let d = DatePhraseParser.parse("in 2 hours", now: Self.referenceNow, calendar: Self.calendar)
        #expect(d != nil)
        if let d = d {
            #expect(abs(d.timeIntervalSince(Self.referenceNow) - 2 * 3600) < 1)
        }
    }

    @Test
    func inDays() {
        let d = DatePhraseParser.parse("3 days from now", now: Self.referenceNow, calendar: Self.calendar)
        #expect(d != nil)
        if let d = d {
            #expect(abs(d.timeIntervalSince(Self.referenceNow) - 3 * 86400) < 60)
        }
    }

    @Test
    func nextSaturdayFromFriday() {
        // Reference is Friday → next saturday is +1 day (00:00)
        let d = DatePhraseParser.parse("next saturday", now: Self.referenceNow, calendar: Self.calendar)
        #expect(d != nil)
        if let d = d {
            let comp = Self.calendar.dateComponents([.year, .month, .day, .weekday], from: d)
            #expect(comp.weekday == 7)  // saturday
            #expect(comp.day == 16)
            #expect(comp.month == 3)
        }
    }

    @Test
    func bareWeekdayUsesNextOccurrence() {
        // Reference is Friday → "monday" without "next" should still be Monday next week.
        let d = DatePhraseParser.parse("monday", now: Self.referenceNow, calendar: Self.calendar)
        #expect(d != nil)
        if let d = d {
            let comp = Self.calendar.dateComponents([.weekday, .day], from: d)
            #expect(comp.weekday == 2)
            #expect(comp.day == 18)  // monday after the reference friday
        }
    }

    @Test
    func threeWeekdaysFromMonday() {
        // 3 weekdays from Monday should be Thursday (skip nothing).
        let d = DatePhraseParser.parse("3 weekdays from monday", now: Self.referenceNow, calendar: Self.calendar)
        #expect(d != nil)
        if let d = d {
            let weekday = Self.calendar.component(.weekday, from: d)
            #expect(weekday == 5)  // thursday
        }
    }

    @Test
    func unparseablePhraseReturnsNil() {
        let d = DatePhraseParser.parse("xyzzy", now: Self.referenceNow, calendar: Self.calendar)
        #expect(d == nil)
    }
}
