import Foundation

/// Resolves natural-language date/time phrases into a concrete Date.
/// First-pass via NSDataDetector, then custom fallbacks for cases
/// NSDataDetector handles poorly ("3 weekdays from monday",
/// "next saturday", "in 20 hours").
enum DatePhraseParser {
    /// Resolves `text` against `now` (default = `Date()`).
    /// Returns nil if no date phrase is found.
    static func parse(_ text: String, now: Date = Date(), calendar: Calendar = .current) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }

        // First try our custom parsers — they handle several phrases
        // NSDataDetector doesn't ("in 20 hours", "next saturday").
        if let d = parseRelative(trimmed, now: now, calendar: calendar) { return d }
        if let d = parseNextWeekday(trimmed, now: now, calendar: calendar) { return d }
        if let d = parseWeekdaysFrom(trimmed, now: now, calendar: calendar) { return d }

        // Fall back to NSDataDetector.
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            if let match = detector.firstMatch(in: trimmed, range: range)?.date {
                return match
            }
        }
        return nil
    }

    // MARK: - Custom parsers

    /// Matches "in 20 hours", "20 hours from now", "in 3 days", "5 minutes from now".
    private static func parseRelative(_ s: String, now: Date, calendar: Calendar) -> Date? {
        let lower = s.lowercased()
        let pattern = #/^(?:in\s+)?(\d+(?:\.\d+)?)\s+(second|minute|hour|day|week|month|year)s?(?:\s+from\s+now)?$/#
        guard let m = lower.wholeMatch(of: pattern) else { return nil }
        let value = Double(m.1) ?? 0
        let unit = String(m.2)
        switch unit {
        case "second": return now.addingTimeInterval(value)
        case "minute": return now.addingTimeInterval(value * 60)
        case "hour":   return now.addingTimeInterval(value * 3600)
        case "day":
            return calendar.date(byAdding: .day, value: Int(value), to: now)
        case "week":
            return calendar.date(byAdding: .day, value: Int(value * 7), to: now)
        case "month":
            return calendar.date(byAdding: .month, value: Int(value), to: now)
        case "year":
            return calendar.date(byAdding: .year, value: Int(value), to: now)
        default: return nil
        }
    }

    /// Matches "next monday", "monday", "next sat", "this friday".
    private static func parseNextWeekday(_ s: String, now: Date, calendar: Calendar) -> Date? {
        let lower = s.lowercased()
        let weekdays: [String: Int] = [
            "sunday": 1, "sun": 1,
            "monday": 2, "mon": 2,
            "tuesday": 3, "tue": 3, "tues": 3,
            "wednesday": 4, "wed": 4,
            "thursday": 5, "thu": 5, "thurs": 5,
            "friday": 6, "fri": 6,
            "saturday": 7, "sat": 7,
        ]
        let trimmedLower = lower
            .replacingOccurrences(of: "next ", with: "")
            .replacingOccurrences(of: "this ", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let target = weekdays[trimmedLower] else { return nil }
        let today = calendar.component(.weekday, from: now)
        var daysAhead = target - today
        if daysAhead < 0 { daysAhead += 7 }
        if daysAhead == 0 && lower.hasPrefix("next") {
            // "next saturday" said ON a saturday → a week from today.
            // Bare "saturday" said on saturday → today.
            daysAhead = 7
        }
        if daysAhead == 0 {
            // "saturday" said on saturday → today (start-of-day).
            return calendar.startOfDay(for: now)
        }
        guard let d = calendar.date(byAdding: .day, value: daysAhead, to: now) else { return nil }
        return calendar.startOfDay(for: d)
    }

    /// Matches "N weekdays from monday", "3 weekdays from now".
    private static func parseWeekdaysFrom(_ s: String, now: Date, calendar: Calendar) -> Date? {
        let lower = s.lowercased()
        let pattern = #/^(\d+)\s+weekdays?\s+from\s+(.+)$/#
        guard let m = lower.wholeMatch(of: pattern) else { return nil }
        let count = Int(m.1) ?? 0
        let fromStr = String(m.2).trimmingCharacters(in: .whitespaces)
        let base: Date
        if fromStr == "now" || fromStr == "today" {
            base = now
        } else if let weekdayBase = parseNextWeekday(fromStr, now: now, calendar: calendar) {
            base = weekdayBase
        } else {
            return nil
        }
        var d = base
        var added = 0
        while added < count {
            d = calendar.date(byAdding: .day, value: 1, to: d) ?? d
            let w = calendar.component(.weekday, from: d)
            if w != 1 && w != 7 { added += 1 }  // skip Sun/Sat
        }
        return d
    }
}
