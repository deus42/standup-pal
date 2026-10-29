import Foundation

/// Time helpers. Times of day are stored as "minutes since midnight".
enum Clock {
    static var calendar: Calendar { Calendar.current }

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    static func minuteOfDay(_ date: Date) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// DST-safe "this day at hh:mm".
    static func date(on day: Date, minute: Int) -> Date {
        let m = max(0, min(minute, 24 * 60 - 1))
        return calendar.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: day) ?? day
    }

    static func dayKey(_ date: Date) -> String { dayKeyFormatter.string(from: date) }
    static func date(fromKey key: String) -> Date? { dayKeyFormatter.date(from: key) }
    static func weekday(_ date: Date) -> Int { calendar.component(.weekday, from: date) }
    static func addDays(_ n: Int, to date: Date) -> Date { calendar.date(byAdding: .day, value: n, to: date) ?? date }
    static func time(_ date: Date) -> String { timeFormatter.string(from: date) }
    static func time(minute: Int) -> String { time(date(on: Date(), minute: minute)) }

    /// Compact countdown for the menu bar: "<1m", "12m", "1h 05m".
    static func shortCountdown(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return "<1m" }
        let m = Int((seconds / 60).rounded(.up))
        if m < 60 { return "\(m)m" }
        return "\(m / 60)h \(String(format: "%02d", m % 60))m"
    }

    /// "4 min", "1 h 20 min".
    static func minutesLabel(_ seconds: TimeInterval) -> String {
        let m = max(1, Int((seconds / 60).rounded(.up)))
        if m < 60 { return "\(m) min" }
        let h = m / 60, r = m % 60
        return r == 0 ? "\(h) h" : "\(h) h \(r) min"
    }

    static func relative(_ seconds: TimeInterval) -> String {
        seconds <= 0 ? "now" : "in \(minutesLabel(seconds))"
    }

    static func mmss(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    static func durationLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        if minutes % 60 == 0 {
            let h = minutes / 60
            return h == 1 ? "1 hour" : "\(h) hours"
        }
        return String(format: "%.1f hours", Double(minutes) / 60)
    }

    /// Weekdays (1 = Sunday … 7 = Saturday) in the user's locale order.
    static var orderedWeekdays: [Int] {
        let first = calendar.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    static func shortWeekdaySymbol(_ weekday: Int) -> String {
        let symbols = calendar.shortWeekdaySymbols
        return symbols[(weekday - 1 + symbols.count) % symbols.count]
    }

    static func daysSummary(_ days: Set<Int>) -> String {
        if days.count == 7 { return "Every day" }
        if days.isEmpty { return "Never" }
        if days == [2, 3, 4, 5, 6] { return "Weekdays" }
        if days == [1, 7] { return "Weekends" }
        return orderedWeekdays.filter { days.contains($0) }.map { shortWeekdaySymbol($0) }.joined(separator: " ")
    }
}
