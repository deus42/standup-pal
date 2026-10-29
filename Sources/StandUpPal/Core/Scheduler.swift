import Combine
import Foundation

struct UpcomingItem: Identifiable, Equatable {
    let id: String
    let date: Date
    let emoji: String
    let title: String
    let isSnoozed: Bool
}

enum ReminderOutcome {
    case stoodUp, done, skipped, expired
}

/// Decides when reminders fire. Ticks once a second; everything is derived from the
/// clock plus persisted bookkeeping, so sleep/wake and relaunches behave.
@MainActor
final class Scheduler: ObservableObject {
    static let shared = Scheduler()

    /// A reminder noticed later than this (Mac asleep, app closed) is silently dropped.
    static let graceSeconds: TimeInterval = 10 * 60
    static let awaySeconds: TimeInterval = 5 * 60
    static let renudgeAfter: TimeInterval = 3 * 60
    static let expireAfter: TimeInterval = 20 * 60
    static let maxHold: TimeInterval = 60 * 60

    @Published private(set) var now = Date()
    @Published private(set) var active: Occurrence?
    @Published private(set) var queue: [Occurrence] = []
    @Published private(set) var holdReason: String?
    @Published private(set) var nextStandup: Date?
    @Published private(set) var upcoming: [UpcomingItem] = []
    @Published private(set) var isWarmUpRunning = false

    var onPresent: ((Occurrence) -> Void)?
    var onDismiss: (() -> Void)?
    var onRenudge: (() -> Void)?

    private let store = AppStore.shared
    private var timer: Timer?
    private var activeShownAt: Date?
    private var renudged = false
    private var forceShowOnce = false

    func start() {
        timer?.invalidate()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        t.tolerance = 0.25
        RunLoop.main.add(t, forMode: .common)
        timer = t
        tick()
    }

    // MARK: Tick

    func tick() {
        let now = Date()
        self.now = now
        rollover(now)

        if let until = store.runtime.pausedUntil, until <= now { store.runtime.pausedUntil = nil }
        let paused = isPaused(now)

        for occ in occurrences(on: now) where occ.due <= now && !store.runtime.firedIDs.contains(occ.id) {
            store.runtime.firedIDs.insert(occ.id)
            guard now.timeIntervalSince(occ.due) <= Self.graceSeconds, !paused else { continue }
            if occ.isStandup, store.settings.smartAway, Presence.idleSeconds() >= Self.awaySeconds {
                // Already away from the desk: that's a stand-up in spirit.
                store.updateToday { $0.away += 1 }
                continue
            }
            enqueue(occ)
        }

        let dueSnoozes = store.runtime.snoozed.filter { $0.due <= now }
        if !dueSnoozes.isEmpty {
            store.runtime.snoozed.removeAll { $0.due <= now }
            if !paused { dueSnoozes.forEach(enqueue) }
        }

        presentIfPossible(now)
        housekeepActive(now)
        refreshUpcoming(now)

        if let toast = store.toast, toast.expires < now { store.toast = nil }
        if store.reaction != nil, store.reactionUntil < now { store.reaction = nil }
    }

    private func rollover(_ now: Date) {
        let key = Clock.dayKey(now)
        guard store.runtime.dayKey != key else { return }
        let firstRun = store.runtime.dayKey.isEmpty
        store.runtime.dayKey = key
        store.runtime.firedIDs = store.runtime.firedIDs.filter { $0.contains("@\(key)") }
        store.runtime.snoozed.removeAll { now.timeIntervalSince($0.due) > 6 * 3600 }
        if !firstRun {
            // A night's rest nudges the mood back towards content.
            store.pet.happiness += (75 - store.pet.happiness) * 0.3
        }
        let cutoff = Clock.dayKey(Clock.addDays(-180, to: now))
        store.stats = store.stats.filter { $0.key >= cutoff }
        store.pet.bestStreak = max(store.pet.bestStreak, store.currentStreak(now: now))
    }

    private func enqueue(_ occ: Occurrence) {
        if active?.id == occ.id || queue.contains(where: { $0.id == occ.id }) { return }
        if occ.isStandup {
            // A fresh stand-up replaces any older pending one.
            queue.removeAll { $0.isStandup }
            store.runtime.snoozed.removeAll { $0.isStandup }
        }
        queue.append(occ)
        queue.sort { $0.due < $1.due }
    }

    private func presentIfPossible(_ now: Date) {
        guard active == nil, !isWarmUpRunning, !queue.isEmpty else {
            if queue.isEmpty, holdReason != nil { holdReason = nil }
            return
        }
        if store.settings.holdDuringCalls, !forceShowOnce, let reason = Presence.callReason() {
            if holdReason != reason { holdReason = reason }
            queue.removeAll { now.timeIntervalSince($0.due) > Self.maxHold }
            return
        }
        forceShowOnce = false
        holdReason = nil
        let next = queue.removeFirst()
        active = next
        activeShownAt = now
        renudged = false
        onPresent?(next)
        SoundPlayer.shared.play(.reminder)
    }

    private func housekeepActive(_ now: Date) {
        guard let active, let shown = activeShownAt else { return }
        let elapsed = now.timeIntervalSince(shown)
        if store.settings.renudge, !renudged, elapsed >= Self.renudgeAfter {
            renudged = true
            SoundPlayer.shared.play(.renudge)
            onRenudge?()
        }
        if elapsed >= Self.expireAfter {
            resolve(active, .expired)
        }
    }

    private func clearActive() {
        active = nil
        activeShownAt = nil
        onDismiss?()
    }

    // MARK: Actions

    func resolve(_ occ: Occurrence, _ outcome: ReminderOutcome) {
        if active?.id == occ.id { clearActive() }
        queue.removeAll { $0.id == occ.id }
        store.runtime.snoozed.removeAll { $0.id == occ.id }

        switch outcome {
        case .stoodUp, .done:
            if occ.isStandup {
                store.updateToday { $0.standupsDone += 1 }
                store.pet.totalStandups += 1
                store.award(xp: 10, happiness: 5)
            } else {
                store.updateToday { $0.extrasDone += 1 }
                store.pet.totalExtras += 1
                store.award(xp: 10, happiness: 4)
            }
            store.react(.happy, for: 5)
            SoundPlayer.shared.play(.success)
        case .skipped:
            if occ.isStandup {
                store.updateToday { $0.skipped += 1 }
                store.adjustHappiness(-6)
            } else {
                store.updateToday { $0.extrasSkipped += 1 }
                store.adjustHappiness(-3)
            }
            store.react(.sad, for: 4)
        case .expired:
            store.updateToday { $0.missed += 1 }
            store.adjustHappiness(occ.isStandup ? -4 : -2)
        }
        afterProgress()
    }

    func snooze(_ occ: Occurrence, minutes: Int) {
        if active?.id == occ.id { clearActive() }
        queue.removeAll { $0.id == occ.id }
        var snoozed = occ
        snoozed.due = Date().addingTimeInterval(TimeInterval(minutes * 60))
        snoozed.snoozeCount += 1
        store.runtime.snoozed.removeAll { $0.id == occ.id }
        store.runtime.snoozed.append(snoozed)
        store.updateToday { $0.snoozed += 1 }
        if occ.isStandup { store.adjustHappiness(-1) }
        SoundPlayer.shared.play(.snooze)
        refreshUpcoming(Date())
    }

    /// Called when a warm-up window opens. Blocks other reminders while it runs.
    func beginWarmUp(from occ: Occurrence?) {
        isWarmUpRunning = true
        if let occ, active?.id == occ.id { clearActive() }
    }

    func endWarmUp() {
        isWarmUpRunning = false
    }

    /// Records a finished (or partly finished) warm-up. Returns the XP awarded.
    @discardableResult
    func completeWarmUp(for occ: Occurrence?, seconds: Double, full: Bool) -> Int {
        let now = Date()
        if let occ {
            queue.removeAll { $0.id == occ.id }
            store.runtime.snoozed.removeAll { $0.id == occ.id }
        } else {
            // A voluntary warm-up counts for the stand-up that's about to fire.
            queue.removeAll { $0.isStandup }
            store.runtime.snoozed.removeAll { $0.isStandup }
            if let next = nextScheduledStandup(after: now), next.due.timeIntervalSince(now) < 20 * 60 {
                store.runtime.firedIDs.insert(next.id)
            }
        }
        let xp = full ? 25 : 15
        store.updateToday {
            $0.standupsDone += 1
            $0.warmUps += 1
            $0.activeSeconds += Int(seconds)
        }
        store.pet.totalStandups += 1
        store.pet.totalWarmUps += 1
        store.award(xp: xp, happiness: full ? 10 : 6)
        store.react(.celebrate, for: 8)
        afterProgress()
        return xp
    }

    func pause(minutes: Int) {
        store.runtime.pausedUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        dropPending()
    }

    func pauseUntilTomorrow() {
        store.runtime.pausedUntil = Clock.calendar.startOfDay(for: Clock.addDays(1, to: Date()))
        dropPending()
    }

    func resume() {
        store.runtime.pausedUntil = nil
        tick()
    }

    func showHeldNow() {
        forceShowOnce = true
        tick()
    }

    private func dropPending() {
        queue.removeAll()
        if active != nil { clearActive() }
        holdReason = nil
        tick()
    }

    private func afterProgress() {
        let today = store.today
        if today.standupsDone >= store.settings.dailyGoal, store.runtime.goalToastDay != store.todayKey {
            store.runtime.goalToastDay = store.todayKey
            if store.toast == nil {
                store.toast = Toast(title: "Daily goal reached! 🏆",
                                    message: "\(today.standupsDone) stand-ups today. \(store.settings.petName) is beaming.")
            }
        }
        store.pet.bestStreak = max(store.pet.bestStreak, store.currentStreak())
        refreshUpcoming(Date())
    }

    // MARK: Queries

    func isPaused(_ now: Date = Date()) -> Bool {
        guard let until = store.runtime.pausedUntil else { return false }
        return until > now
    }

    func isWorkingTime(_ date: Date) -> Bool {
        let s = store.settings
        guard s.workDays.contains(Clock.weekday(date)) else { return false }
        let m = Clock.minuteOfDay(date)
        return m >= s.workStartMinute && m < s.workEndMinute
    }

    /// Stand-ups land `leadMinutes` before each clock-aligned slot ends (e.g. :55 every hour).
    static func standupMinutes(_ s: AppSettings) -> [Int] {
        let interval = max(15, s.intervalMinutes)
        guard s.workEndMinute > s.workStartMinute else { return [] }
        return (s.workStartMinute..<s.workEndMinute).filter { m in
            let inLunch = s.lunchEnabled && m >= s.lunchStartMinute && m < s.lunchEndMinute
            return (m + s.leadMinutes) % interval == 0 && !inLunch
        }
    }

    func occurrences(on day: Date) -> [Occurrence] {
        let s = store.settings
        let key = Clock.dayKey(day)
        let weekday = Clock.weekday(day)
        var list: [Occurrence] = []
        if s.workDays.contains(weekday) {
            for m in Self.standupMinutes(s) {
                let date = Clock.date(on: day, minute: m)
                list.append(Occurrence(id: "standup@\(key)T\(m)", kind: .standup, scheduled: date, due: date))
            }
        }
        for reminder in store.reminders where reminder.isEnabled && reminder.weekdays.contains(weekday) {
            for m in reminder.minutes {
                let date = Clock.date(on: day, minute: m)
                list.append(Occurrence(id: "extra-\(reminder.id.uuidString)@\(key)T\(m)",
                                       kind: .custom(reminder.id), scheduled: date, due: date))
            }
        }
        return list.sorted { $0.due < $1.due }
    }

    func nextScheduledStandup(after date: Date) -> Occurrence? {
        for offset in 0...7 {
            let day = Clock.addDays(offset, to: date)
            if let occ = occurrences(on: day).first(where: {
                $0.isStandup && $0.due > date && !store.runtime.firedIDs.contains($0.id)
            }) {
                return occ
            }
        }
        return nil
    }

    func reminder(for occ: Occurrence) -> CustomReminder? {
        guard let id = occ.customID else { return nil }
        return store.reminders.first { $0.id == id }
    }

    private func refreshUpcoming(_ now: Date) {
        let from = isPaused(now) ? (store.runtime.pausedUntil ?? now) : now
        var next = nextScheduledStandup(after: from)?.due
        if let snoozed = store.runtime.snoozed.filter(\.isStandup).map(\.due).min() {
            next = min(next ?? snoozed, snoozed)
        }
        if next != nextStandup { nextStandup = next }

        var items: [UpcomingItem] = []
        for occ in store.runtime.snoozed where !occ.isStandup {
            if let r = reminder(for: occ) {
                items.append(UpcomingItem(id: occ.id, date: occ.due, emoji: r.emoji, title: r.title, isSnoozed: true))
            }
        }
        for occ in occurrences(on: now) where !occ.isStandup && occ.due > now && !store.runtime.firedIDs.contains(occ.id) {
            if let r = reminder(for: occ) {
                items.append(UpcomingItem(id: occ.id, date: occ.due, emoji: r.emoji, title: r.title, isSnoozed: false))
            }
        }
        items.sort { $0.date < $1.date }
        let trimmed = Array(items.prefix(4))
        if trimmed != upcoming { upcoming = trimmed }
    }

    func petMood(at now: Date = Date()) -> PetMood {
        if active != nil || (holdReason != nil && !queue.isEmpty) { return .alert }
        if let reaction = store.reaction, store.reactionUntil > now { return reaction }
        if isPaused(now) || !isWorkingTime(now) { return .sleepy }
        if store.pet.happiness < 30 { return .sad }
        return .idle
    }
}
