import Foundation

/// Where the pet is in its day. It dresses for work in work hours, has coffee in
/// pyjamas before, unwinds at home in pyjamas after, and sleeps from bedtime on.
enum DayPhase: String, CaseIterable, Codable {
    case morning, work, home, night
}

enum DayRhythm {
    /// Until this time the night is still on.
    static let morningStartMinute = 5 * 60
    /// On days off the coffee morning lasts until here.
    static let dayOffMorningEndMinute = 11 * 60
    /// While you're still at the Mac after bedtime, the pet asks again this often.
    static let bedtimeRepeat: TimeInterval = 30 * 60
    static let bedtimeChoices = Array(stride(from: 19 * 60, through: 23 * 60 + 30, by: 30))

    static func phase(at date: Date, settings s: AppSettings) -> DayPhase {
        let m = Clock.minuteOfDay(date)
        let workday = s.workDays.contains(Clock.weekday(date))
        // Work hours win, even when they run past bedtime.
        if workday, m >= s.workStartMinute, m < s.workEndMinute { return .work }
        if m >= s.bedtimeMinute || m < morningStartMinute { return .night }
        if workday { return m < s.workStartMinute ? .morning : .home }
        return m < dayOffMorningEndMinute ? .morning : .home
    }

    /// Whether the pet should send you to bed now. The caller checks that you're
    /// actually at the Mac.
    static func bedtimeNudgeDue(now: Date, last: Date?, settings s: AppSettings) -> Bool {
        guard s.bedtimeNudge, phase(at: now, settings: s) == .night else { return false }
        guard let last, last <= now else { return true }
        return now.timeIntervalSince(last) >= bedtimeRepeat
    }
}
