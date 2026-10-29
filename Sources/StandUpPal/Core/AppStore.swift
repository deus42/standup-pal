import Combine
import Foundation
import SwiftUI

/// Single source of truth for everything persisted, plus a few transient UI signals.
@MainActor
final class AppStore: ObservableObject {
    static let shared = AppStore()

    @Published var settings: AppSettings { didSet { if settings != oldValue { scheduleSave() } } }
    @Published var reminders: [CustomReminder] { didSet { if reminders != oldValue { scheduleSave() } } }
    @Published var pet: PetState { didSet { if pet != oldValue { scheduleSave() } } }
    @Published var stats: [String: DayStats] { didSet { if stats != oldValue { scheduleSave() } } }
    @Published var runtime: RuntimeState { didSet { if runtime != oldValue { scheduleSave() } } }

    // Transient
    @Published var reaction: PetMood?
    @Published var reactionUntil: Date = .distantPast
    @Published var toast: Toast?
    @Published var talkNonce = 0
    @Published var showWelcome = false

    private var saveWork: DispatchWorkItem?

    private enum Key {
        static let settings = "settings.v1"
        static let reminders = "reminders.v1"
        static let pet = "pet.v1"
        static let stats = "stats.v1"
        static let runtime = "runtime.v1"
    }

    private init() {
        settings = Self.load(Key.settings) ?? AppSettings()
        reminders = Self.load(Key.reminders) ?? CustomReminder.defaults
        pet = Self.load(Key.pet) ?? PetState()
        stats = Self.load(Key.stats) ?? [:]
        runtime = Self.load(Key.runtime) ?? RuntimeState()
    }

    // MARK: Persistence

    private static func load<T: Decodable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.saveNow() }
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    func saveNow() {
        saveWork?.cancel()
        saveWork = nil
        let encoder = JSONEncoder()
        func put<T: Encodable>(_ value: T, _ key: String) {
            if let data = try? encoder.encode(value) { UserDefaults.standard.set(data, forKey: key) }
        }
        put(settings, Key.settings)
        put(reminders, Key.reminders)
        put(pet, Key.pet)
        put(stats, Key.stats)
        put(runtime, Key.runtime)
    }

    // MARK: Convenience

    var petRGB: RGB { RGB(hex: settings.petColorHex) }
    var petColor: Color { petRGB.color }
    /// A deeper tone of the pet colour that keeps white text readable.
    var accent: Color { petRGB.darker(0.42).color }
    var petLook: PetLook { PetLook.from(settings) }

    var todayKey: String { Clock.dayKey(Date()) }
    var today: DayStats { stats[todayKey] ?? DayStats() }

    func updateToday(_ change: (inout DayStats) -> Void) {
        var day = stats[todayKey] ?? DayStats()
        change(&day)
        stats[todayKey] = day
    }

    func react(_ mood: PetMood, for seconds: TimeInterval = 4) {
        reaction = mood
        reactionUntil = Date().addingTimeInterval(seconds)
        talkNonce += 1
    }

    func adjustHappiness(_ delta: Double) {
        pet.happiness = min(100, max(0, pet.happiness + delta))
    }

    func award(xp: Int, happiness delta: Double) {
        let oldLevel = pet.level
        pet.xp += xp
        adjustHappiness(delta)
        let newLevel = pet.level
        guard newLevel > oldLevel else { return }
        let unlocked = PetAccessory.allCases.filter { $0.unlockLevel > oldLevel && $0.unlockLevel <= newLevel }
        var message = "\(settings.petName) reached level \(newLevel)!"
        if let accessory = unlocked.last {
            message += " New look unlocked: \(accessory.emoji) \(accessory.label)."
        }
        toast = Toast(title: "Level up! 🎉", message: message)
        SoundPlayer.shared.play(.levelUp)
    }

    /// Consecutive days meeting the daily goal. Non-work days never break a streak.
    func currentStreak(now: Date = Date()) -> Int {
        let goal = max(1, settings.dailyGoal)
        var streak = (stats[Clock.dayKey(now)]?.standupsDone ?? 0) >= goal ? 1 : 0
        var day = Clock.addDays(-1, to: now)
        for _ in 0..<400 {
            let done = stats[Clock.dayKey(day)]?.standupsDone ?? 0
            if done >= goal {
                streak += 1
            } else if settings.workDays.contains(Clock.weekday(day)) {
                break
            }
            day = Clock.addDays(-1, to: day)
        }
        return streak
    }

    func resetProgress() {
        pet = PetState()
        stats = [:]
        settings.petAccessory = .none
        react(.happy, for: 3)
    }
}
