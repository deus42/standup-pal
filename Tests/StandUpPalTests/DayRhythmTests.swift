import Foundation
import Testing
@testable import StandUpPal

@Suite("The pet's day: outfits and bedtime")
struct DayRhythmTests {
    private func day(_ weekday: Int) throws -> Date {
        try #require(Clock.calendar.nextDate(after: Date(), matching: DateComponents(weekday: weekday), matchingPolicy: .nextTime))
    }

    private func at(_ day: Date, _ h: Int, _ m: Int = 0) -> Date { Clock.date(on: day, minute: h * 60 + m) }

    @Test func workdayRunsMorningWorkHomeNight() throws {
        let s = AppSettings()
        let monday = try day(2)
        #expect(DayRhythm.phase(at: at(monday, 4, 59), settings: s) == .night)
        #expect(DayRhythm.phase(at: at(monday, 7, 30), settings: s) == .morning)
        #expect(DayRhythm.phase(at: at(monday, 9), settings: s) == .work)
        #expect(DayRhythm.phase(at: at(monday, 17, 59), settings: s) == .work)
        #expect(DayRhythm.phase(at: at(monday, 18), settings: s) == .home)
        #expect(DayRhythm.phase(at: at(monday, 19, 59), settings: s) == .home)
        #expect(DayRhythm.phase(at: at(monday, 20), settings: s) == .night)
        #expect(DayRhythm.phase(at: at(monday, 23, 30), settings: s) == .night)
    }

    @Test func daysOffHaveALongCoffeeMorningAndNoWork() throws {
        let s = AppSettings()
        let saturday = try day(7)
        #expect(DayRhythm.phase(at: at(saturday, 10), settings: s) == .morning)
        #expect(DayRhythm.phase(at: at(saturday, 14), settings: s) == .home)
        #expect(DayRhythm.phase(at: at(saturday, 21), settings: s) == .night)
    }

    @Test func lateWorkHoursWinOverBedtime() throws {
        var s = AppSettings()
        s.workEndMinute = 21 * 60
        s.bedtimeMinute = 20 * 60
        let tuesday = try day(3)
        #expect(DayRhythm.phase(at: at(tuesday, 20, 30), settings: s) == .work)
        #expect(DayRhythm.phase(at: at(tuesday, 21), settings: s) == .night)
    }

    @Test func bedtimeNudgesRepeatEveryHalfHourThroughTheNight() throws {
        let s = AppSettings()
        let monday = try day(2)
        #expect(!DayRhythm.bedtimeNudgeDue(now: at(monday, 19, 50), last: nil, settings: s))
        #expect(DayRhythm.bedtimeNudgeDue(now: at(monday, 20), last: nil, settings: s))
        #expect(!DayRhythm.bedtimeNudgeDue(now: at(monday, 20, 20), last: at(monday, 20), settings: s))
        #expect(DayRhythm.bedtimeNudgeDue(now: at(monday, 20, 30), last: at(monday, 20), settings: s))
        // Past midnight it's still the same night.
        let tuesday = Clock.addDays(1, to: monday)
        #expect(DayRhythm.bedtimeNudgeDue(now: at(tuesday, 1), last: at(monday, 23, 40), settings: s))
        // Morning: no more nudges, whatever happened last night.
        #expect(!DayRhythm.bedtimeNudgeDue(now: at(tuesday, 6), last: at(tuesday, 4, 50), settings: s))
        var off = s
        off.bedtimeNudge = false
        #expect(!DayRhythm.bedtimeNudgeDue(now: at(monday, 21), last: nil, settings: off))
    }

    @Test func outfitsSwapTheGymGear() {
        let look = PetLook(species: .bear, color: RGB(hex: "#DDA772"), head: .cap, hands: .dumbbells, neck: .medal)
        let work = look.dressed(for: .work)
        #expect(work.outfit == .work && work.head == .cap && work.hands == .dumbbells && work.neck == .none)
        for phase in [DayPhase.morning, .home, .night] {
            let cosy = look.dressed(for: phase)
            #expect(cosy.outfit == phase && cosy.head == .none && cosy.hands == .none && cosy.neck == .none)
        }
        #expect(look.dressed(for: nil) == look)
    }

    @Test func oldSettingsAndRuntimeDecodeWithDefaults() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"petName":"Bo"}"#.utf8))
        #expect(settings.dayOutfits && settings.bedtimeNudge && settings.bedtimeMinute == 20 * 60)
        let runtime = try JSONDecoder().decode(RuntimeState.self, from: Data(#"{"dayKey":"2026-11-02"}"#.utf8))
        #expect(runtime.bedtimeNudgedAt == nil)
    }

    @MainActor
    @Test func goingToBedWhenAskedCountsTowardsSleepyhead() {
        let store = AppStore.shared
        store.settings.soundEnabled = false
        let before = store.pet.totalBedtimes
        let xp = store.pet.xp
        Scheduler.shared.wentToBed()
        #expect(store.pet.totalBedtimes == before + 1 && store.pet.xp == xp + 3)
        var context = store.achievementContext
        context.pet.totalBedtimes = 7
        #expect(AchievementCatalog.unlocked(in: context).contains("bed7"))
    }

    @MainActor
    @Test func petIsAwakeAtHomeAndAsleepAtNight() {
        let scheduler = Scheduler.shared
        AppStore.shared.reaction = nil
        AppStore.shared.runtime.pausedUntil = nil
        scheduler.phaseOverride = .home
        #expect(scheduler.petMood() == .idle)
        scheduler.phaseOverride = .morning
        #expect(scheduler.dressedLook().outfit == (AppStore.shared.settings.dayOutfits ? .morning : nil))
        scheduler.phaseOverride = .night
        #expect(scheduler.petMood() == .sleepy)
        scheduler.phaseOverride = nil
    }
}
