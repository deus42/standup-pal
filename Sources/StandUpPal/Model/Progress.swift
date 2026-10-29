import Foundation

/// The pet's long-term progress.
struct PetState: Codable, Equatable {
    var xp = 0
    var happiness: Double = 70
    var totalStandups = 0
    var totalWarmUps = 0
    var totalExtras = 0
    var bestStreak = 0

    var level: Int { Self.levelInfo(xp: xp).level }

    static func xpNeeded(forLevel level: Int) -> Int { 50 + 25 * (level - 1) }

    /// Level, XP gained inside that level, XP needed to finish it.
    static func levelInfo(xp: Int) -> (level: Int, into: Int, needed: Int) {
        var level = 1
        var remaining = max(0, xp)
        while remaining >= xpNeeded(forLevel: level) {
            remaining -= xpNeeded(forLevel: level)
            level += 1
        }
        return (level, remaining, xpNeeded(forLevel: level))
    }
}

extension PetState {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        xp = c.value(.xp, xp)
        happiness = c.value(.happiness, happiness)
        totalStandups = c.value(.totalStandups, totalStandups)
        totalWarmUps = c.value(.totalWarmUps, totalWarmUps)
        totalExtras = c.value(.totalExtras, totalExtras)
        bestStreak = c.value(.bestStreak, bestStreak)
    }
}

struct DayStats: Codable, Equatable {
    var standupsDone = 0
    var warmUps = 0
    var skipped = 0
    var snoozed = 0
    var missed = 0
    var away = 0
    var extrasDone = 0
    var extrasSkipped = 0
    var activeSeconds = 0
}

extension DayStats {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        standupsDone = c.value(.standupsDone, 0)
        warmUps = c.value(.warmUps, 0)
        skipped = c.value(.skipped, 0)
        snoozed = c.value(.snoozed, 0)
        missed = c.value(.missed, 0)
        away = c.value(.away, 0)
        extrasDone = c.value(.extrasDone, 0)
        extrasSkipped = c.value(.extrasSkipped, 0)
        activeSeconds = c.value(.activeSeconds, 0)
    }
}

/// Scheduler bookkeeping that must survive relaunches.
struct RuntimeState: Codable, Equatable {
    var dayKey = ""
    var firedIDs: Set<String> = []
    var snoozed: [Occurrence] = []
    var pausedUntil: Date?
    var hasOnboarded = false
    var goalToastDay = ""
}

extension RuntimeState {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dayKey = c.value(.dayKey, "")
        firedIDs = c.value(.firedIDs, [])
        snoozed = c.value(.snoozed, [])
        pausedUntil = c.value(.pausedUntil, nil)
        hasOnboarded = c.value(.hasOnboarded, false)
        goalToastDay = c.value(.goalToastDay, "")
    }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var message: String
    var expires = Date().addingTimeInterval(90)
}
