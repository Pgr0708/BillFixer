import Foundation

/// API dates are "YYYY-MM-DD" (calendar days, no time zone) — keep them that way end to end.
nonisolated enum DateHelpers {
    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    static func parseDay(_ s: String) -> Date? {
        let parts = s.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// Local calendar date → "YYYY-MM-DD".
    static func dayString(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 2000, c.month ?? 1, c.day ?? 1)
    }

    /// "Mar 15, 2024"
    static func display(_ day: String?) -> String? {
        guard let day, let date = parseDay(day) else { return nil }
        return date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: TimeZone(identifier: "UTC")!))
    }

    static func display(_ date: Date?) -> String? {
        date?.formatted(date: .abbreviated, time: .omitted)
    }

    /// "Mar 16 · 9:12 AM"
    static func timeline(_ date: Date?) -> String {
        guard let date else { return "" }
        return "\(date.formatted(.dateTime.month(.abbreviated).day())) · \(date.formatted(date: .omitted, time: .shortened))"
    }

    /// Whole days from today to a YYYY-MM-DD day (negative = overdue).
    static func daysUntil(_ day: String) -> Int? {
        guard let target = parseDay(day) else { return nil }
        let today = parseDay(dayString(Date()))!
        return calendar.dateComponents([.day], from: today, to: target).day
    }

    static func dueLabel(_ day: String) -> String {
        guard let d = daysUntil(day) else { return day }
        switch d {
        case ..<0: return "Overdue by \(-d) day\(d == -1 ? "" : "s")"
        case 0: return "Due today"
        case 1: return "Due tomorrow"
        default: return "Due in \(d) days"
        }
    }

    /// Local Date for a YYYY-MM-DD day at a given hour (for reminders).
    static func localDate(_ day: String, hour: Int = 9) -> Date? {
        let parts = day.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: hour))
    }

    static func greeting(_ now: Date = Date()) -> String {
        switch Calendar.current.component(.hour, from: now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }
}
