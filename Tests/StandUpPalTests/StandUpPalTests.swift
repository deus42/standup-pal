import Foundation
import Testing
@testable import StandUpPal

@MainActor
@Suite("Scheduling rules")
struct SchedulingTests {
    private func hm(_ h: Int, _ m: Int) -> Int { h * 60 + m }

    @Test func hourlyStandUpsLandFiveMinutesBeforeEachHour() {
        let minutes = Scheduler.standupMinutes(AppSettings())
        #expect(minutes == (9...17).map { hm($0, 55) })
    }

    @Test func halfHourlyAddsTheHalfPastSlots() {
        var s = AppSettings()
        s.intervalMinutes = 30
        let minutes = Scheduler.standupMinutes(s)
        #expect(minutes.first == hm(9, 25))
        #expect(minutes.last == hm(17, 55))
        #expect(minutes.count == 18)
    }

    @Test func leadTimeAndLunchBreakAreRespected() {
        var s = AppSettings()
        s.leadMinutes = 10
        s.lunchEnabled = true
        s.lunchStartMinute = hm(13, 0)
        s.lunchEndMinute = hm(14, 0)
        let minutes = Scheduler.standupMinutes(s)
        #expect(minutes.first == hm(9, 50))
        #expect(minutes.contains(hm(12, 50)))
        #expect(!minutes.contains(hm(13, 50)))
    }

    @Test func invalidWorkingHoursProduceNothing() {
        var s = AppSettings()
        s.workStartMinute = hm(18, 0)
        s.workEndMinute = hm(9, 0)
        #expect(Scheduler.standupMinutes(s).isEmpty)
    }

    @Test func customReminderTimesAreSortedAndUnique() {
        let reminder = CustomReminder(times: [hm(16, 30), hm(11, 30), hm(16, 30)])
        #expect(reminder.minutes == [hm(11, 30), hm(16, 30)])
    }

    @Test func customReminderIntervalsStayInsideTheirWindow() {
        let reminder = CustomReminder(mode: .interval, intervalMinutes: 120, startMinute: hm(10, 0), endMinute: hm(18, 0))
        #expect(reminder.minutes == [hm(10, 0), hm(12, 0), hm(14, 0), hm(16, 0), hm(18, 0)])
    }

    @Test func occurrencesCoverStandUpsAndEnabledExtrasOnWorkDays() throws {
        let store = AppStore.shared
        store.settings = AppSettings()
        store.reminders = CustomReminder.defaults
        let monday = try #require(Clock.calendar.nextDate(after: Date(), matching: DateComponents(weekday: 2),
                                                          matchingPolicy: .nextTime))
        let occurrences = Scheduler.shared.occurrences(on: monday)
        #expect(occurrences.filter(\.isStandup).count == 9)
        // Only "10 push-ups" is enabled by default: 11:30 and 16:30.
        let extras = occurrences.filter { !$0.isStandup }
        #expect(extras.map { Clock.minuteOfDay($0.due) } == [hm(11, 30), hm(16, 30)])
        #expect(Set(occurrences.map(\.id)).count == occurrences.count)

        let sunday = Clock.addDays(-1, to: monday)
        #expect(Scheduler.shared.occurrences(on: sunday).isEmpty)
    }
}

@MainActor
@Suite("Reminder flows")
struct FlowTests {
    private func makeExtra() -> Occurrence {
        let store = AppStore.shared
        store.settings.soundEnabled = false
        let id = store.reminders.first?.id ?? UUID()
        let now = Date()
        return Occurrence(id: "extra-test-\(UUID().uuidString)", kind: .custom(id), scheduled: now, due: now)
    }

    @Test func snoozingAnExtraPushesItBackByTheChosenHours() throws {
        let store = AppStore.shared
        let occ = makeExtra()
        let snoozedBefore = store.today.snoozed
        Scheduler.shared.snooze(occ, minutes: 120)
        let snoozed = try #require(store.runtime.snoozed.first { $0.id == occ.id })
        #expect(abs(snoozed.due.timeIntervalSinceNow - 7200) < 5)
        #expect(snoozed.snoozeCount == 1)
        #expect(store.today.snoozed == snoozedBefore + 1)
        Scheduler.shared.resolve(snoozed, .skipped)
        #expect(!store.runtime.snoozed.contains { $0.id == occ.id })
    }

    @Test func finishingAnExtraAwardsXPAndCountsIt() {
        let store = AppStore.shared
        let occ = makeExtra()
        let xp = store.pet.xp
        let done = store.today.extrasDone
        Scheduler.shared.resolve(occ, .done)
        #expect(store.pet.xp == xp + 10)
        #expect(store.today.extrasDone == done + 1)
    }

    @Test func aFullWarmUpCountsAsAStandUp() {
        let store = AppStore.shared
        store.settings.soundEnabled = false
        let xp = store.pet.xp
        let done = store.today.standupsDone
        let awarded = Scheduler.shared.completeWarmUp(for: nil, seconds: 180, full: true)
        #expect(awarded == 25)
        #expect(store.pet.xp == xp + 25)
        #expect(store.today.standupsDone == done + 1)
    }
}

@Suite("Progress, persistence and routines")
struct ModelTests {
    @Test func levelsGetProgressivelyLonger() {
        #expect(PetState.levelInfo(xp: 0) == (1, 0, 50))
        #expect(PetState.levelInfo(xp: 50) == (2, 0, 75))
        #expect(PetState.levelInfo(xp: 124) == (2, 74, 75))
        #expect(PetState.levelInfo(xp: 125) == (3, 0, 100))
    }

    @Test func emptySavedSettingsDecodeToDefaults() throws {
        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        #expect(decoded == AppSettings())
    }

    @Test func unknownSavedValuesFallBackInsteadOfFailing() throws {
        let json = #"{"soundChoice":"airHorn","petName":"Bloop","intervalMinutes":30}"#
        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        #expect(decoded.soundChoice == .softChime)
        #expect(decoded.petName == "Bloop")
        #expect(decoded.intervalMinutes == 30)
    }

    @Test func settingsRoundTrip() throws {
        var s = AppSettings()
        s.petSpecies = .booty
        s.petHands = .dumbbells
        s.petNeck = .medal
        s.petBellyHex = "#FFD677"
        s.language = .uk
        s.workDays = [2, 4, 6]
        s.customExercises = [Exercise(id: "custom-1", name: "Lunges", emoji: "🦵", instructions: "Alternate legs.", seconds: 40, isCustom: true)]
        let data = try JSONEncoder().encode(s)
        #expect(try JSONDecoder().decode(AppSettings.self, from: data) == s)
    }

    @Test(arguments: WarmUpLength.allCases)
    func routinesFitTheChosenLength(length: WarmUpLength) {
        for _ in 0..<50 {
            let routine = ExerciseLibrary.routine(totalSeconds: length.rawValue, settings: AppSettings())
            let total = routine.reduce(0) { $0 + $1.seconds }
            #expect(total <= length.rawValue + 5)
            #expect(Double(total) >= Double(length.rawValue) * 0.75)
            #expect(routine.first?.slot == .opener)
            #expect(routine.last?.slot == .closer)
            #expect(Set(routine.map(\.id)).count == routine.count)
        }
    }

    @Test func routinesSkipDisabledExercisesAndPreferCustomOnes() {
        var s = AppSettings()
        s.disabledExerciseIDs = ["squats", "neck", "eyes"]
        s.customExercises = [Exercise(id: "custom-lunge", name: "Lunges", emoji: "🦵", instructions: "", seconds: 30, isCustom: true)]
        for _ in 0..<30 {
            let ids = ExerciseLibrary.routine(totalSeconds: 180, settings: s).map(\.id)
            #expect(ids.allSatisfy { !s.disabledExerciseIDs.contains($0) })
            #expect(ids.contains("custom-lunge"))
        }
    }

    @Test func countdownLabels() {
        #expect(Clock.shortCountdown(30, in: .en) == "<1m")
        #expect(Clock.shortCountdown(60, in: .en) == "1m")
        #expect(Clock.shortCountdown(61, in: .en) == "2m")
        #expect(Clock.shortCountdown(3600, in: .en) == "1h 00m")
        #expect(Clock.shortCountdown(720, in: .uk) == "12 хв")
        #expect(Clock.shortCountdown(3900, in: .ru) == "1 ч 05 мин")
        #expect(Clock.mmss(29.2) == "0:30")
    }

    @Test func settingsFromVersionOneKeepTheirHeadAccessory() throws {
        let crown = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"petAccessory":"crown"}"#.utf8))
        #expect(crown.petHead == .crown)
        let partyHat = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"petAccessory":"partyHat"}"#.utf8))
        #expect(partyHat.petHead == .sweatband)
        let explicit = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"petAccessory":"crown","petHead":"cap"}"#.utf8))
        #expect(explicit.petHead == .cap)
    }

    @Test func palettesAreDistinctAndValid() {
        let all = PetPalette.all
        #expect(all.count >= 28)
        #expect(Set(all.map(\.id)).count == all.count)
        #expect(Set(all.map { $0.body.uppercased() }).count == all.count)
        for palette in all {
            #expect(RGB(hex: palette.body).hex == palette.body.uppercased())
            #expect(RGB(hex: palette.belly).luminance > RGB(hex: palette.body).luminance - 0.05)
            #expect(palette.name != palette.id)
        }
    }

    @Test func gearUnlocksInOrderAndStartsWithTheSweatband() {
        #expect(HeadGear.sweatband.unlockLevel == 1)
        #expect(AppSettings().petHead == .sweatband)
        #expect(GearCatalog.unlocked(after: 1, through: 1).isEmpty)
        #expect(GearCatalog.unlocked(after: 1, through: 3).count == 2)
        #expect(GearCatalog.next(after: 1)?.level == 2)
        #expect(GearCatalog.next(after: 99) == nil)
        let levels = HeadGear.allCases.map(\.unlockLevel) + HandGear.allCases.map(\.unlockLevel) + NeckGear.allCases.map(\.unlockLevel)
        #expect(levels.filter { $0 > 1 }.count == Set(levels.filter { $0 > 1 }).count)
    }
}

@Suite("Languages")
struct LanguageTests {
    @Test(arguments: [(1, 0), (2, 1), (4, 1), (5, 2), (11, 2), (12, 2), (21, 0), (22, 1), (25, 2), (111, 2), (102, 1)])
    func slavicPluralForms(n: Int, index: Int) {
        #expect(Plural.slavicIndex(n) == index)
    }

    @Test func countedWordsReadNaturally() {
        #expect(Words.breaks(1, in: .en) == "1 stand-up")
        #expect(Words.breaks(6, in: .en) == "6 stand-ups")
        #expect(Words.breaks(1, in: .uk) == "1 перерва")
        #expect(Words.breaks(3, in: .uk) == "3 перерви")
        #expect(Words.breaks(6, in: .uk) == "6 перерв")
        #expect(Words.breaks(2, in: .ru) == "2 перерыва")
        #expect(Words.breaks(5, in: .ru) == "5 перерывов")
        #expect(Words.days(21, in: .uk) == "21 день")
        #expect(Clock.durationLabel(90, in: .uk) == "1,5 години")
        #expect(Clock.durationLabel(120, in: .ru) == "2 часа")
        #expect(Clock.everyLabel(60, in: .uk) == "Щогодини")
        #expect(Clock.everyLabel(120, in: .en) == "Every 2 hours")
        #expect(Clock.everyLabel(30, in: .ru) == "Каждые 30 мин")
    }

    @Test func eachLanguageGetsItsOwnText() {
        let texts = Lang.allCases.map { tr("Settings", "Налаштування", "Настройки", in: $0) }
        #expect(texts == ["Settings", "Налаштування", "Настройки"])
        #expect(AppLanguage.uk.resolved == .uk)
        #expect(AppLanguage.ru.resolved == .ru)
    }

    @Test func defaultRemindersFollowALanguageSwitchButCustomTitlesStay() {
        let pushUps = CustomReminder(title: "10 віджимань", note: "З колін — теж зараховується.")
        let renamed = CustomReminder(title: "Plank", note: "My own note")
        #expect(pushUps.relocalized(in: .ru).title == "10 отжиманий")
        #expect(pushUps.relocalized(in: .ru).note == "С колен — тоже засчитывается.")
        #expect(pushUps.relocalized(in: .en).title == "10 push-ups")
        #expect(renamed.relocalized(in: .uk) == renamed)
    }
}

@MainActor
@Suite("Live tick")
struct TickTests {
    /// A clean scheduler with one extra reminder `offset` minutes from now and no stand-ups.
    @discardableResult
    private func prepare(minuteOffset offset: Int) -> CustomReminder {
        let store = AppStore.shared
        var settings = AppSettings()
        settings.workDays = []
        settings.soundEnabled = false
        settings.holdDuringCalls = false
        store.settings = settings
        Scheduler.shared.pause(minutes: 1) // drops anything queued or on screen
        store.runtime = RuntimeState(dayKey: Clock.dayKey(Date()))
        let reminder = CustomReminder(title: "Test", emoji: "🧪",
                                      times: [Clock.minuteOfDay(Date()) + offset], weekdays: Set(1...7))
        store.reminders = [reminder]
        return reminder
    }

    @Test func aDueReminderIsPresentedOnTheNextTick() throws {
        let reminder = prepare(minuteOffset: 0)
        Scheduler.shared.tick()
        let active = try #require(Scheduler.shared.active)
        #expect(active.customID == reminder.id)
        Scheduler.shared.resolve(active, .skipped)
        Scheduler.shared.tick()
        #expect(Scheduler.shared.active == nil)
    }

    @Test func aStaleReminderIsDroppedSilently() {
        prepare(minuteOffset: -15)
        Scheduler.shared.tick()
        #expect(Scheduler.shared.active == nil)
        #expect(AppStore.shared.runtime.firedIDs.contains { $0.hasPrefix("extra-") })
    }

    @Test func pausedRemindersStayQuiet() {
        prepare(minuteOffset: 0)
        Scheduler.shared.pause(minutes: 30)
        Scheduler.shared.tick()
        #expect(Scheduler.shared.active == nil)
        Scheduler.shared.resume()
    }
}

@Suite("Presence probes")
struct PresenceTests {
    @Test func probesAnswerWithoutPermissions() {
        #expect(Presence.idleSeconds() >= 0)
        let reason = Presence.callReason()
        #expect(reason == nil || reason == "camera" || reason == "microphone")
    }
}
