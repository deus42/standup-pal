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
        Form {
            Section {
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        StatTile(title: "Today", value: "\(today.standupsDone)/\(store.settings.dailyGoal)",
                                 caption: goalCaption(today.standupsDone))
                        StatTile(title: "Streak", value: streakText, caption: "best \(store.pet.bestStreak)")
                        StatTile(title: "Level", value: "\(store.pet.level)", caption: "\(store.pet.xp) XP total")
                    }
                    GridRow {
                        StatTile(title: "Stand-ups", value: "\(store.pet.totalStandups)", caption: "all time")
                        StatTile(title: "Warm-ups", value: "\(store.pet.totalWarmUps)", caption: "\(totalMinutes) min moving")
                        StatTile(title: "Extras", value: "\(store.pet.totalExtras)", caption: "done")
                    }
                }
            }

            Section("Last 14 days") {
                Chart {
                    ForEach(points) { point in
                        BarMark(x: .value("Day", point.date, unit: .day),
                                y: .value("Stand-ups", point.done))
                            .foregroundStyle(store.accent.gradient)
                            .cornerRadius(5)
                    }
                    RuleMark(y: .value("Goal", store.settings.dailyGoal))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("goal").font(.caption2).foregroundStyle(.secondary)
                        }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                    }
                }
                .frame(height: 170)
                .padding(.vertical, 6)
            }

            Section("Today in detail") {
                LabeledContent("Stand-ups done", value: "\(today.standupsDone)")
                LabeledContent("…with a full warm-up", value: "\(today.warmUps)")
                LabeledContent("Extra exercises done", value: "\(today.extrasDone)")
                LabeledContent("Snoozed", value: "\(today.snoozed)")
                LabeledContent("Skipped", value: "\(today.skipped + today.extrasSkipped)")
                LabeledContent("Auto-skipped (you were away)", value: "\(today.away)")
                LabeledContent("Ignored", value: "\(today.missed)")
            }
        }
        .formStyle(.grouped)
    }

    private var streakText: String {
        let streak = store.currentStreak()
        return streak > 0 ? "\(streak) 🔥" : "0"
    }

    private func goalCaption(_ done: Int) -> String {
        let left = store.settings.dailyGoal - done
        return left > 0 ? "\(left) to go" : "goal reached!"
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
