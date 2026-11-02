import Foundation

/// One week of progress, for the shareable Friday card.
struct WeeklySummary: Equatable {
    struct Day: Equatable {
        let date: Date
        let standups: Int
    }

    let start: Date
    let days: [Day]
    let standups: Int
    let warmUps: Int
    let minutes: Int
    let eyeBreaks: Int
    let extras: Int
    let goalDays: Int

    var bestDay: Day? { days.max { $0.standups < $1.standups }.flatMap { $0.standups > 0 ? $0 : nil } }

    /// The week (in the user's own week order) that contains `date`.
    static func weekStart(containing date: Date, calendar: Calendar = Clock.calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    static func make(weekStart start: Date, stats: [String: DayStats], dailyGoal: Int) -> WeeklySummary {
        let days = (0..<7).map { Clock.addDays($0, to: start) }
        let entries = days.map { stats[Clock.dayKey($0)] ?? DayStats() }
        return WeeklySummary(
            start: start,
            days: zip(days, entries).map { Day(date: $0, standups: $1.standupsDone) },
            standups: entries.reduce(0) { $0 + $1.standupsDone },
            warmUps: entries.reduce(0) { $0 + $1.warmUps },
            minutes: entries.reduce(0) { $0 + $1.activeSeconds } / 60,
            eyeBreaks: entries.reduce(0) { $0 + $1.eyeBreaks },
            extras: entries.reduce(0) { $0 + $1.extrasDone },
            goalDays: entries.filter { $0.standupsDone >= max(1, dailyGoal) }.count)
    }

    /// The week whose card is due: the one holding the latest Friday whose working day
    /// has ended. Works whichever day the user's week starts on.
    static func dueWeekStart(now: Date, settings: AppSettings) -> Date {
        var day = now
        for _ in 0..<8 {
            let isFriday = Clock.weekday(day) == 6
            let isToday = Clock.calendar.isDate(day, inSameDayAs: now)
            if isFriday, !isToday || Clock.minuteOfDay(now) >= settings.workEndMinute { break }
            day = Clock.addDays(-1, to: day)
        }
        return weekStart(containing: day)
    }
}
