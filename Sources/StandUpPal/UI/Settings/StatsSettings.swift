import Charts
import SwiftUI

struct StatsSettings: View {
    @EnvironmentObject var store: AppStore
    let actions: AppActions

    private struct DayPoint: Identifiable {
        let id: String
        let date: Date
        let done: Int
    }

    var body: some View {
        let today = store.today
        let points = lastDays(14)
        let totalMinutes = store.stats.values.reduce(0) { $0 + $1.activeSeconds } / 60
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                StatTile(title: tr("Today", "Сьогодні", "Сегодня"), value: "\(today.standupsDone)/\(store.settings.dailyGoal)",
                         caption: goalCaption(today.standupsDone))
                StatTile(title: tr("Streak", "Серія", "Серия"), value: streakText,
                         caption: tr("best \(store.pet.bestStreak)", "рекорд \(store.pet.bestStreak)", "рекорд \(store.pet.bestStreak)"))
                StatTile(title: tr("Level", "Рівень", "Уровень"), value: "\(store.pet.level)",
                         caption: tr("\(store.pet.xp) XP total", "усього \(store.pet.xp) XP", "всего \(store.pet.xp) XP"))
                StatTile(title: tr("Stand-ups", "Перерви", "Перерывы"), value: "\(store.pet.totalStandups)",
                         caption: tr("all time", "за весь час", "за всё время"))
                StatTile(title: tr("Warm-ups", "Розминки", "Разминки"), value: "\(store.pet.totalWarmUps)",
                         caption: tr("\(totalMinutes) min moving", "\(totalMinutes) хв руху", "\(totalMinutes) мин движения"))
                StatTile(title: tr("Extras", "Додаткові", "Доп."), value: "\(store.pet.totalExtras)",
                         caption: tr("done", "виконано", "выполнено"))
            }

            SettingsGroup(title: tr("Last 14 days", "Останні 14 днів", "Последние 14 дней")) {
                Chart {
                    ForEach(points) { point in
                        BarMark(x: .value(tr("Day", "День", "День"), point.date, unit: .day),
                                y: .value(tr("Stand-ups", "Перерви", "Перерывы"), point.done))
                            .foregroundStyle(store.accent.gradient)
                            .cornerRadius(5)
                    }
                    RuleMark(y: .value(tr("Goal", "Мета", "Цель"), store.settings.dailyGoal))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text(tr("goal", "мета", "цель")).font(.caption2).foregroundStyle(.secondary)
                        }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow).locale(L10n.locale), centered: true)
                    }
                }
                .frame(height: 170)
                .padding(14)
            }

            SettingsGroup(title: tr("Achievements", "Досягнення", "Достижения") + " · \(unlockedCount)/\(AchievementCatalog.all.count)") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 9), spacing: 8) {
                    ForEach(AchievementCatalog.all) { achievement in
                        badge(achievement)
                    }
                }
                .padding(10)
            }

            HStack(spacing: 12) {
                Text(todayLine(today))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button(tr("Week card", "Картка тижня", "Карточка недели")) { actions.showWeekly() }
                    .buttonStyle(PillButtonStyle(compact: true))
                    .fixedSize()
            }
        }
    }

    private var unlockedCount: Int { AchievementCatalog.unlocked(in: store.achievementContext).count }

    private func badge(_ achievement: Achievement) -> some View {
        let context = store.achievementContext
        let unlocked = achievement.isUnlocked(context)
        return VStack(spacing: 3) {
            Text(achievement.emoji)
                .font(.system(size: 22))
                .frame(width: 44, height: 44)
                .background(Circle().fill(unlocked ? store.petColor.opacity(0.35) : Color.primary.opacity(0.05)))
                .overlay(Circle().strokeBorder(unlocked ? store.accent : Color.clear, lineWidth: 1.5))
                .grayscale(unlocked ? 0 : 1)
                .opacity(unlocked ? 1 : 0.4)
            Text(achievement.title)
                .font(.system(size: 9.5, weight: unlocked ? .semibold : .regular))
                .foregroundStyle(unlocked ? Color.primary : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .help("\(achievement.title): \(achievement.detail) · \(achievement.progress(context))/\(achievement.target)")
    }

    private func todayLine(_ today: DayStats) -> String {
        tr("Today: \(today.warmUps) warm-ups · \(today.extrasDone) extras · \(today.water) 💧 · \(today.eyeBreaks) 👀 · \(today.snoozed) snoozed · \(today.skipped + today.extrasSkipped) skipped",
           "Сьогодні: розминок \(today.warmUps) · додаткових \(today.extrasDone) · \(today.water) 💧 · \(today.eyeBreaks) 👀 · відкладено \(today.snoozed) · пропущено \(today.skipped + today.extrasSkipped)",
           "Сегодня: разминок \(today.warmUps) · дополнительных \(today.extrasDone) · \(today.water) 💧 · \(today.eyeBreaks) 👀 · отложено \(today.snoozed) · пропущено \(today.skipped + today.extrasSkipped)")
    }

    private var streakText: String {
        let streak = store.currentStreak()
        return streak > 0 ? "\(streak) 🔥" : "0"
    }

    private func goalCaption(_ done: Int) -> String {
        let left = store.settings.dailyGoal - done
        return left > 0 ? tr("\(left) to go", "ще \(left)", "ещё \(left)") : tr("🎯 goal reached", "🎯 виконано", "🎯 выполнено")
    }

    private func lastDays(_ count: Int) -> [DayPoint] {
        let now = Date()
        return (0..<count).reversed().map { offset in
            let date = Clock.calendar.startOfDay(for: Clock.addDays(-offset, to: now))
            let key = Clock.dayKey(date)
            return DayPoint(id: key, date: date, done: store.stats[key]?.standupsDone ?? 0)
        }
    }
}
