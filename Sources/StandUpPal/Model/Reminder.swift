import Foundation

/// A user-defined extra reminder ("10 push-ups at 11:30").
struct CustomReminder: Codable, Identifiable, Equatable {
    enum Mode: String, Codable, CaseIterable, Identifiable {
        case times, interval
        var id: String { rawValue }
    }

    var id = UUID()
    var title = "New reminder"
    var emoji = "⭐️"
    var note = ""
    var isEnabled = true
    var mode: Mode = .times
    var times: [Int] = [11 * 60]
    var intervalMinutes = 120
    var startMinute = 10 * 60
    var endMinute = 18 * 60
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]

    /// Minutes of the day this reminder fires on an active weekday.
    var minutes: [Int] {
        switch mode {
        case .times:
            return Array(Set(times)).sorted()
        case .interval:
            let step = max(15, intervalMinutes)
            guard endMinute >= startMinute else { return [] }
            return Array(stride(from: startMinute, through: endMinute, by: step))
        }
    }

    var scheduleSummary: String {
        let days = Clock.daysSummary(weekdays)
        switch mode {
        case .times:
            let list = minutes.map { Clock.time(minute: $0) }.joined(separator: ", ")
            return list.isEmpty ? "No times set" : "\(list) · \(days)"
        case .interval:
            return "Every \(Clock.durationLabel(intervalMinutes)), \(Clock.time(minute: startMinute))–\(Clock.time(minute: endMinute)) · \(days)"
        }
    }

    static var defaults: [CustomReminder] {
        [
            CustomReminder(title: "10 push-ups", emoji: "💪", note: "Knees on the floor totally counts.",
                           isEnabled: true, mode: .times, times: [11 * 60 + 30, 16 * 60 + 30]),
            CustomReminder(title: "Drink some water", emoji: "💧", note: "A full glass, nice and slow.",
                           isEnabled: false, mode: .interval, intervalMinutes: 120, startMinute: 10 * 60, endMinute: 18 * 60),
            CustomReminder(title: "Take a short walk", emoji: "🚶", note: "Five minutes around the block or the office.",
                           isEnabled: false, mode: .times, times: [14 * 60 + 30]),
        ]
    }
}

extension CustomReminder {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, id)
        title = c.value(.title, title)
        emoji = c.value(.emoji, emoji)
        note = c.value(.note, note)
        isEnabled = c.value(.isEnabled, isEnabled)
        mode = c.value(.mode, mode)
        times = c.value(.times, times)
        intervalMinutes = c.value(.intervalMinutes, intervalMinutes)
        startMinute = c.value(.startMinute, startMinute)
        endMinute = c.value(.endMinute, endMinute)
        weekdays = c.value(.weekdays, weekdays)
    }
}

enum ReminderKind: Codable, Hashable {
    case standup
    case custom(UUID)
}

/// One concrete firing of a reminder.
struct Occurrence: Codable, Identifiable, Hashable {
    var id: String
    var kind: ReminderKind
    var scheduled: Date
    var due: Date
    var snoozeCount = 0
    var isPreview = false

    var isStandup: Bool {
        if case .standup = kind { return true }
        return false
    }

    var customID: UUID? {
        if case .custom(let id) = kind { return id }
        return nil
    }
}
