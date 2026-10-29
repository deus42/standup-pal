import Charts
import SwiftUI

struct StatsSettings: View {
    @EnvironmentObject var store: AppStore

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

            SettingsGroup(title: tr("Today in detail", "Сьогодні докладно", "Сегодня подробно")) {
                Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                    detailRow(tr("Stand-ups done", "Перерв зроблено", "Перерывов сделано"), today.standupsDone,
                              tr("…with a full warm-up", "…з повною розминкою", "…с полной разминкой"), today.warmUps)
                    Divider()
                    detailRow(tr("Extra exercises done", "Додаткових вправ", "Дополнительных упражнений"), today.extrasDone,
                              tr("Snoozed", "Відкладено", "Отложено"), today.snoozed)
                    Divider()
                    detailRow(tr("Skipped", "Пропущено", "Пропущено"), today.skipped + today.extrasSkipped,
                              tr("Auto-skipped while away", "Автопропуск (тебе не було)", "Автопропуск (тебя не было)"), today.away)
                    Divider()
                    detailRow(tr("Ignored", "Проігноровано", "Проигнорировано"), today.missed, nil, nil)
                }
            }
        }
    }

    private func detailRow(_ a: String, _ av: Int, _ b: String?, _ bv: Int?) -> some View {
        GridRow {
            cell(a, av)
            if let b, let bv {
                cell(b, bv)
            } else {
                Color.clear.frame(height: 1)
            }
        }
    }

    private func cell(_ title: String, _ value: Int) -> some View {
        HStack {
            Text(title).font(.system(size: 13))
            Spacer(minLength: 8)
            Text("\(value)").font(.system(size: 13, weight: .semibold)).monospacedDigit()
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
        .frame(maxWidth: .infinity)
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
