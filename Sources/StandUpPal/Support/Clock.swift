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

    nonisolated(unsafe) private static var cachedTimeFormatter: DateFormatter?
    nonisolated(unsafe) private static var cachedSymbols: [String]?

    /// English keeps the user's own 12/24-hour preference; Ukrainian and Russian use 24 hours.
    private static var timeFormatter: DateFormatter {
        if let cachedTimeFormatter { return cachedTimeFormatter }
        let f = DateFormatter()
        if L10n.lang == .en {
            f.locale = L10n.locale
            f.dateStyle = .none
            f.timeStyle = .short
        } else {
            f.locale = L10n.locale
            f.dateFormat = "HH:mm"
        }
        cachedTimeFormatter = f
        return f
    }

    static func languageDidChange() {
        cachedTimeFormatter = nil
        cachedSymbols = nil
    }

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

    /// "Friday 09:55" for dates beyond today.
    static func dayAndTime(_ date: Date, wide: Bool = true) -> String {
        let f = DateFormatter()
        f.locale = L10n.locale
        f.setLocalizedDateFormatFromTemplate(wide ? "EEEE" : "EEE")
        return "\(f.string(from: date).capitalized(with: L10n.locale)) \(time(date))"
    }

    /// Compact countdown for the menu bar: "<1m", "12m", "1h 05m".
    static func shortCountdown(_ seconds: TimeInterval, in lang: Lang = L10n.lang) -> String {
        let m = Int((seconds / 60).rounded(.up))
        switch lang {
        case .en:
            if seconds < 60 { return "<1m" }
            if m < 60 { return "\(m)m" }
            return "\(m / 60)h \(String(format: "%02d", m % 60))m"
        case .uk, .ru:
            let min = tr("", "хв", "мин", in: lang)
            let hour = tr("", "год", "ч", in: lang)
            if seconds < 60 { return "<1 \(min)" }
            if m < 60 { return "\(m) \(min)" }
            return "\(m / 60) \(hour) \(String(format: "%02d", m % 60)) \(min)"
        }
    }

    /// "4 min", "1 h 20 min".
    static func minutesLabel(_ seconds: TimeInterval, in lang: Lang = L10n.lang) -> String {
        let m = max(1, Int((seconds / 60).rounded(.up)))
        if m < 60 { return Words.minutes(m, in: lang) }
        let h = m / 60, r = m % 60
        return r == 0 ? Words.hoursShort(h, in: lang) : "\(Words.hoursShort(h, in: lang)) \(Words.minutes(r, in: lang))"
    }

    static func relative(_ seconds: TimeInterval) -> String {
        if seconds <= 0 { return tr("now", "зараз", "сейчас") }
        return tr("in \(minutesLabel(seconds))", "через \(minutesLabel(seconds))", "через \(minutesLabel(seconds))")
    }

    static func mmss(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// "30 min", "1 hour", "1.5 hours".
    static func durationLabel(_ minutes: Int, in lang: Lang = L10n.lang) -> String {
        if minutes < 60 { return Words.minutes(minutes, in: lang) }
        if minutes % 60 == 0 { return Words.hours(minutes / 60, in: lang) }
        let value = Double(minutes) / 60
        switch lang {
        case .en: return String(format: "%.1f hours", value)
        case .uk: return String(format: "%.1f години", value).replacingOccurrences(of: ".", with: ",")
        case .ru: return String(format: "%.1f часа", value).replacingOccurrences(of: ".", with: ",")
        }
    }

    /// "Every hour", "Every 2 hours", "Кожні 30 хв".
    static func everyLabel(_ minutes: Int, in lang: Lang = L10n.lang) -> String {
        if minutes == 60 { return tr("Every hour", "Щогодини", "Каждый час", in: lang) }
        let amount: String
        if minutes < 60 {
            amount = Words.minutes(minutes, in: lang)
        } else if minutes % 60 == 0 {
            amount = lang == .en ? Words.hours(minutes / 60, in: lang) : Words.hoursShort(minutes / 60, in: lang)
        } else {
            amount = durationLabel(minutes, in: lang)
        }
        return tr("Every \(amount)", "Кожні \(amount)", "Каждые \(amount)", in: lang)
    }

    /// Weekdays (1 = Sunday … 7 = Saturday) in the user's own week order.
    static var orderedWeekdays: [Int] {
        let first = calendar.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    static func shortWeekdaySymbol(_ weekday: Int) -> String {
        let symbols: [String]
        if let cachedSymbols {
            symbols = cachedSymbols
        } else {
            var localized = Calendar(identifier: .gregorian)
            localized.locale = L10n.locale
            symbols = localized.shortWeekdaySymbols.map { $0.replacingOccurrences(of: ".", with: "").capitalized(with: L10n.locale) }
            cachedSymbols = symbols
        }
        return symbols[(weekday - 1 + symbols.count) % symbols.count]
    }

    static func daysSummary(_ days: Set<Int>) -> String {
        if days.count == 7 { return tr("Every day", "Щодня", "Каждый день") }
        if days.isEmpty { return tr("Never", "Ніколи", "Никогда") }
        if days == [2, 3, 4, 5, 6] { return tr("Weekdays", "Будні", "Будни") }
        if days == [1, 7] { return tr("Weekends", "Вихідні", "Выходные") }
        return orderedWeekdays.filter { days.contains($0) }.map { shortWeekdaySymbol($0) }.joined(separator: " ")
    }
}
