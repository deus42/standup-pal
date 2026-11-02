import Foundation
import Testing
@testable import StandUpPal

@Suite("Habits, achievements and the weekly card")
struct HabitTests {
    private func hm(_ h: Int, _ m: Int) -> Int { h * 60 + m }

    @MainActor
    @Test func eyeBreaksStayClearOfStandUpsAndLunch() {
        var s = AppSettings()
        s.eyeBreakMinutes = 30
        // Hourly stand-ups at :55 push the :00 slots out; :30 remains.
        #expect(Scheduler.eyeBreakMinutes(s) == (9...17).map { hm($0, 30) })
        s.eyeBreakMinutes = 20
        #expect(Scheduler.eyeBreakMinutes(s).prefix(3) == [hm(9, 20), hm(9, 40), hm(10, 20)])
        s.lunchEnabled = true
        s.lunchStartMinute = hm(13, 0)
        s.lunchEndMinute = hm(14, 0)
        #expect(!Scheduler.eyeBreakMinutes(s).contains { $0 >= hm(13, 0) && $0 < hm(14, 0) })
        for m in Scheduler.eyeBreakMinutes(s) {
            #expect(Scheduler.standupMinutes(s).allSatisfy { abs($0 - m) > 5 })
        }
    }

    @MainActor
    @Test func eyeBreakOccurrencesHaveTheirOwnIDsAndAreNotExtras() throws {
        let store = AppStore.shared
        store.settings = AppSettings()
        store.reminders = []
        let monday = try #require(Clock.calendar.nextDate(after: Date(), matching: DateComponents(weekday: 2), matchingPolicy: .nextTime))
        let occurrences = Scheduler.shared.occurrences(on: monday)
        let eyes = occurrences.filter(\.isEyeBreak)
        #expect(eyes.count == 9)
        #expect(eyes.allSatisfy { $0.id.hasPrefix("eyes@") && $0.customID == nil && !$0.isStandup })
        store.settings.eyeBreaksEnabled = false
        #expect(Scheduler.shared.occurrences(on: monday).filter(\.isEyeBreak).isEmpty)
        store.settings = AppSettings()
        store.reminders = CustomReminder.defaults
    }

    @Test func newCountersSyncAdditivelyAndDecodeFromOldData() throws {
        let a = DayStats(water: 3, eyeBreaks: 2)
        let b = DayStats(water: 4, eyeBreaks: 1)
        #expect(ProgressMath.plus(a, b) == DayStats(water: 7, eyeBreaks: 3))
        let pet = ProgressMath.plus(PetState(totalWater: 5, totalEyeBreaks: 2), PetState(totalWater: 1, totalEyeBreaks: 3))
        #expect(pet.totalWater == 6 && pet.totalEyeBreaks == 5)
        let old = try JSONDecoder().decode(DayStats.self, from: Data(#"{"standupsDone":4}"#.utf8))
        #expect(old.water == 0 && old.eyeBreaks == 0 && old.standupsDone == 4)
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        #expect(settings.waterGoal == 8 && settings.eyeBreaksEnabled && settings.eyeBreakMinutes == 30 && !settings.petWalks)
    }

    @Test func achievementsUnlockAtTheirThresholds() {
        var context = AchievementContext(pet: PetState(), stats: [:], dailyGoal: 6, streak: 0)
        #expect(AchievementCatalog.unlocked(in: context).isEmpty)
        context.pet.totalStandups = 10
        context.pet.totalWarmUps = 1
        context.stats = ["2026-11-02": DayStats(standupsDone: 6, water: 8)]
        context.streak = 3
        let unlocked = AchievementCatalog.unlocked(in: context)
        #expect(unlocked.isSuperset(of: ["standup1", "standup10", "warmup1", "streak3", "water8"]))
        #expect(!unlocked.contains("standup50") && !unlocked.contains("goal5"))
        #expect(Set(AchievementCatalog.all.map(\.id)).count == AchievementCatalog.all.count)
    }

    @MainActor
    @Test func aWaterReminderCountsAGlass() {
        let store = AppStore.shared
        store.settings.soundEnabled = false
        var reminder = CustomReminder(title: "Water", emoji: "💧")
        reminder.tracksWater = true
        store.reminders = [reminder]
        let water = store.today.water
        let occ = Occurrence(id: "extra-water-\(UUID().uuidString)", kind: .custom(reminder.id), scheduled: Date(), due: Date())
        Scheduler.shared.resolve(occ, .done)
        #expect(store.today.water == water + 1)
        store.reminders = CustomReminder.defaults
    }

    @Test func weeklySummaryAddsUpTheWeek() {
        let start = Clock.calendar.startOfDay(for: Date(timeIntervalSince1970: 1_793_000_000))
        var stats: [String: DayStats] = [:]
        stats[Clock.dayKey(start)] = DayStats(standupsDone: 6, warmUps: 3, activeSeconds: 600, water: 5)
        stats[Clock.dayKey(Clock.addDays(2, to: start))] = DayStats(standupsDone: 2, eyeBreaks: 4)
        stats[Clock.dayKey(Clock.addDays(8, to: start))] = DayStats(standupsDone: 9)
        let summary = WeeklySummary.make(weekStart: start, stats: stats, dailyGoal: 6)
        #expect(summary.standups == 8 && summary.warmUps == 3 && summary.minutes == 10 && summary.water == 5)
        #expect(summary.eyeBreaks == 4 && summary.goalDays == 1 && summary.days.count == 7)
        #expect(summary.bestDay?.standups == 6)
    }

    @Test func theCardIsDueForTheWeekWhoseFridayHasEnded() throws {
        let settings = AppSettings()
        let cal = Clock.calendar
        let friday = try #require(cal.nextDate(after: Date(), matching: DateComponents(weekday: 6), matchingPolicy: .nextTime))
        let beforeEnd = Clock.date(on: friday, minute: settings.workEndMinute - 30)
        let afterEnd = Clock.date(on: friday, minute: settings.workEndMinute + 5)
        let saturday = Clock.addDays(1, to: afterEnd)
        let thisWeek = WeeklySummary.weekStart(containing: friday)
        #expect(WeeklySummary.dueWeekStart(now: afterEnd, settings: settings) == thisWeek)
        #expect(WeeklySummary.dueWeekStart(now: saturday, settings: settings) == thisWeek)
        #expect(WeeklySummary.dueWeekStart(now: beforeEnd, settings: settings) == WeeklySummary.weekStart(containing: Clock.addDays(-7, to: friday)))
    }
}
