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
    /// A guided routine to run when the reminder pops up (e.g. physiotherapy).
    var program: ReminderProgram? = nil
    /// Marking it done also counts a glass of water.
    var tracksWater = false

    var hasProgram: Bool { !(program?.steps.isEmpty ?? true) }

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
            return list.isEmpty ? tr("No times set", "Час не задано", "Время не задано") : "\(list) · \(days)"
        case .interval:
            return "\(Clock.everyLabel(intervalMinutes)), \(Clock.time(minute: startMinute))–\(Clock.time(minute: endMinute)) · \(days)"
        }
    }

    static let maxCount = 8
    static let maxTimes = 6

    // Default texts are kept in all three languages so a later language switch can
    // translate reminders the user hasn't renamed.
    private static let templates: [(title: Phrase, note: Phrase)] = [
        (Phrase(en: "10 push-ups", uk: "10 віджимань", ru: "10 отжиманий"),
         Phrase(en: "Knees on the floor totally counts.", uk: "З колін — теж зараховується.", ru: "С колен — тоже засчитывается.")),
        (Phrase(en: "Drink some water", uk: "Випий води", ru: "Выпей воды"),
         Phrase(en: "A full glass, nice and slow.", uk: "Повну склянку, не поспішаючи.", ru: "Полный стакан, не спеша.")),
        (Phrase(en: "Take a short walk", uk: "Коротка прогулянка", ru: "Короткая прогулка"),
         Phrase(en: "Five minutes around the block or the office.", uk: "П'ять хвилин навколо будинку чи офісу.",
                ru: "Пять минут вокруг дома или офиса.")),
        (Phrase(en: "Squats", uk: "Присідання", ru: "Приседания"),
         Phrase(en: "10 slow ones. You've got this.", uk: "10 повільних. Ти зможеш.", ru: "10 медленных. У тебя получится.")),
    ]

    static var defaults: [CustomReminder] {
        [
            CustomReminder(title: templates[0].title.current, emoji: "💪", note: templates[0].note.current,
                           isEnabled: true, mode: .times, times: [11 * 60 + 30, 16 * 60 + 30]),
            CustomReminder(title: templates[1].title.current, emoji: "💧", note: templates[1].note.current,
                           isEnabled: false, mode: .interval, intervalMinutes: 120, startMinute: 10 * 60, endMinute: 18 * 60,
                           tracksWater: true),
            CustomReminder(title: templates[2].title.current, emoji: "🚶", note: templates[2].note.current,
                           isEnabled: false, mode: .times, times: [14 * 60 + 30]),
        ]
    }

    /// What the "+" button adds.
    static var suggestion: CustomReminder {
        CustomReminder(title: templates[3].title.current, emoji: "🦵", note: templates[3].note.current, times: [15 * 60 + 30])
    }

    /// Default titles and notes in the current language; anything the user typed stays.
    func relocalized(in lang: Lang = L10n.lang) -> CustomReminder {
        var copy = self
        for template in Self.templates {
            if template.title.matches(title) { copy.title = template.title.text(in: lang) }
            if template.note.matches(note) { copy.note = template.note.text(in: lang) }
        }
        return copy
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
        program = c.value(.program, nil)
        tracksWater = c.value(.tracksWater, false)
    }
}

/// One exercise in a reminder's program.
struct ProgramStep: Codable, Equatable, Identifiable {
    var id = UUID()
    var exerciseID: String
    var seconds: Int
}

extension ProgramStep {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, UUID())
        exerciseID = c.value(.exerciseID, "reach")
        seconds = c.value(.seconds, 30)
    }
}

/// Steps repeated for a number of sets, with a rest between sets.
struct ReminderProgram: Codable, Equatable {
    var steps: [ProgramStep] = []
    var sets = 1
    var restSeconds = 30

    static let maxSteps = 8

    var totalSeconds: Int {
        let once = steps.reduce(0) { $0 + $1.seconds }
        return once * max(1, sets) + restSeconds * max(0, sets - 1)
    }
}

extension ReminderProgram {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        steps = c.value(.steps, steps)
        sets = c.value(.sets, sets)
        restSeconds = c.value(.restSeconds, restSeconds)
    }
}

/// Ready-made programs built from the exercise library.
enum ProgramPreset: String, CaseIterable, Identifiable {
    case neckShoulders, lowerBack, wristsEyes, legs

    var id: String { rawValue }

    var name: String {
        switch self {
        case .neckShoulders: return tr("Neck & shoulders", "Шия й плечі", "Шея и плечи")
        case .lowerBack: return tr("Lower back", "Поперек", "Поясница")
        case .wristsEyes: return tr("Wrists & eyes", "Зап'ястки й очі", "Запястья и глаза")
        case .legs: return tr("Legs", "Ноги", "Ноги")
        }
    }

    var program: ReminderProgram {
        func steps(_ list: [(String, Int)]) -> [ProgramStep] { list.map { ProgramStep(exerciseID: $0.0, seconds: $0.1) } }
        switch self {
        case .neckShoulders:
            return ReminderProgram(steps: steps([("neck", 30), ("chintuck", 30), ("shoulders", 30), ("blades", 30), ("chest", 30)]),
                                   sets: 2, restSeconds: 20)
        case .lowerBack:
            return ReminderProgram(steps: steps([("backbend", 30), ("hips", 30), ("twist", 30), ("hamstrings", 30), ("sidebend", 30)]),
                                   sets: 2, restSeconds: 20)
        case .wristsEyes:
            return ReminderProgram(steps: steps([("wrists", 30), ("shake", 20), ("eyes", 20), ("breathe", 30)]), sets: 1, restSeconds: 0)
        case .legs:
            return ReminderProgram(steps: steps([("march", 30), ("calves", 30), ("squats", 40), ("ankles", 30), ("deskpushups", 40)]),
                                   sets: 2, restSeconds: 30)
        }
    }
}

enum ReminderKind: Codable, Hashable {
    case standup
    case custom(UUID)
    /// A 20-second look into the distance (20-20-20).
    case eyeBreak
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

    var isEyeBreak: Bool { kind == .eyeBreak }
}
