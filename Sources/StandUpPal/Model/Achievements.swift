import Foundation

/// What achievements are judged on: the merged progress from all Macs.
struct AchievementContext {
    var pet: PetState
    var stats: [String: DayStats]
    var dailyGoal: Int
    var streak: Int

    var level: Int { pet.level }
    var bestStreak: Int { max(pet.bestStreak, streak) }
    var goalDays: Int { stats.values.filter { $0.standupsDone >= max(1, dailyGoal) }.count }
    var bestWaterDay: Int { stats.values.map(\.water).max() ?? 0 }
}

struct Achievement: Identifiable {
    let id: String
    let emoji: String
    let title: String
    let detail: String
    let target: Int
    let value: (AchievementContext) -> Int

    func progress(_ context: AchievementContext) -> Int { min(target, value(context)) }
    func isUnlocked(_ context: AchievementContext) -> Bool { value(context) >= target }
}

enum AchievementCatalog {
    static var all: [Achievement] {
        [
            Achievement(id: "standup1", emoji: "🌱", title: tr("First step", "Перший крок", "Первый шаг"),
                        detail: tr("Your first stand-up", "Перша перерва", "Первый перерыв"), target: 1) { $0.pet.totalStandups },
            Achievement(id: "standup10", emoji: "🧍", title: tr("Up and about", "На ногах", "На ногах"),
                        detail: tr("10 stand-ups", "10 перерв", "10 перерывов"), target: 10) { $0.pet.totalStandups },
            Achievement(id: "standup50", emoji: "🚶", title: tr("Regular", "Постійний гість", "Постоянный гость"),
                        detail: tr("50 stand-ups", "50 перерв", "50 перерывов"), target: 50) { $0.pet.totalStandups },
            Achievement(id: "standup100", emoji: "💯", title: tr("Hundred club", "Клуб сотні", "Клуб сотни"),
                        detail: tr("100 stand-ups", "100 перерв", "100 перерывов"), target: 100) { $0.pet.totalStandups },
            Achievement(id: "standup500", emoji: "🏔️", title: tr("Summit", "Вершина", "Вершина"),
                        detail: tr("500 stand-ups", "500 перерв", "500 перерывов"), target: 500) { $0.pet.totalStandups },
            Achievement(id: "warmup1", emoji: "🤸", title: tr("Warmed up", "Розім'ятися — є", "Размяться — есть"),
                        detail: tr("Your first full warm-up", "Перша повна розминка", "Первая полная разминка"), target: 1) { $0.pet.totalWarmUps },
            Achievement(id: "warmup25", emoji: "🔥", title: tr("On fire", "У вогні", "В огне"),
                        detail: tr("25 warm-ups", "25 розминок", "25 разминок"), target: 25) { $0.pet.totalWarmUps },
            Achievement(id: "warmup100", emoji: "🏅", title: tr("Warm-up pro", "Профі розминки", "Профи разминки"),
                        detail: tr("100 warm-ups", "100 розминок", "100 разминок"), target: 100) { $0.pet.totalWarmUps },
            Achievement(id: "streak3", emoji: "✨", title: tr("Three in a row", "Три поспіль", "Три подряд"),
                        detail: tr("Daily goal 3 days running", "Денна мета 3 дні поспіль", "Дневная цель 3 дня подряд"), target: 3) { $0.bestStreak },
            Achievement(id: "streak7", emoji: "🗓️", title: tr("Full week", "Цілий тиждень", "Целая неделя"),
                        detail: tr("Daily goal 7 days running", "Денна мета 7 днів поспіль", "Дневная цель 7 дней подряд"), target: 7) { $0.bestStreak },
            Achievement(id: "streak30", emoji: "👑", title: tr("Unstoppable", "Нестримність", "Неудержимость"),
                        detail: tr("Daily goal 30 days running", "Денна мета 30 днів поспіль", "Дневная цель 30 дней подряд"), target: 30) { $0.bestStreak },
            Achievement(id: "goal5", emoji: "🎯", title: tr("Bullseye", "У яблучко", "В яблочко"),
                        detail: tr("Daily goal reached on 5 days", "Денна мета виконана 5 днів", "Дневная цель выполнена 5 дней"), target: 5) { $0.goalDays },
            Achievement(id: "water8", emoji: "💧", title: tr("Hydrated", "Вода — є", "Вода — есть"),
                        detail: tr("8 glasses of water in a day", "8 склянок води за день", "8 стаканов воды за день"), target: 8) { $0.bestWaterDay },
            Achievement(id: "eyes100", emoji: "👀", title: tr("Eagle eyes", "Орлиний зір", "Орлиное зрение"),
                        detail: tr("100 eye breaks", "100 перерв для очей", "100 перерывов для глаз"), target: 100) { $0.pet.totalEyeBreaks },
            Achievement(id: "extras25", emoji: "💪", title: tr("Extra mile", "Ще трохи", "Ещё немного"),
                        detail: tr("25 extra reminders done", "25 додаткових нагадувань", "25 дополнительных напоминаний"), target: 25) { $0.pet.totalExtras },
            Achievement(id: "level5", emoji: "⭐️", title: tr("Rising star", "Висхідна зірка", "Восходящая звезда"),
                        detail: tr("Reach level 5", "Досягни рівня 5", "Достигни уровня 5"), target: 5) { $0.level },
            Achievement(id: "level10", emoji: "🌟", title: tr("Superstar", "Суперзірка", "Суперзвезда"),
                        detail: tr("Reach level 10", "Досягни рівня 10", "Достигни уровня 10"), target: 10) { $0.level },
            Achievement(id: "allgear", emoji: "🏆", title: tr("Fully kitted", "Повна екіпіровка", "Полная экипировка"),
                        detail: tr("Unlock every piece of gear (level 15)", "Відкрий усе спорядження (рівень 15)",
                                   "Открой всё снаряжение (уровень 15)"), target: 15) { $0.level },
        ]
    }

    static func unlocked(in context: AchievementContext) -> Set<String> {
        Set(all.filter { $0.isUnlocked(context) }.map(\.id))
    }
}
