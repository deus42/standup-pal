import SwiftUI

/// Small healthy habits around the stand-ups: water, eye breaks, the weekly card and the
/// walking pet.
struct HabitsSettings: View {
    @EnvironmentObject var store: AppStore
    let actions: AppActions

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(spacing: 16) {
                SettingsGroup(title: tr("Water", "Вода", "Вода"),
                              footer: tr("Tap + in the menu bar popover after each glass. A reminder can count glasses too: tick \"Counts a glass of water\" in Reminders.",
                                         "Тисни + у меню біля значка після кожної склянки. Нагадування теж може рахувати склянки: познач «Рахує склянку води» в Нагадуваннях.",
                                         "Жми + в меню у значка после каждого стакана. Напоминание тоже может считать стаканы: отметь «Засчитывает стакан воды» в Напоминаниях.")) {
                    SettingsRow(title: tr("Daily goal", "Денна мета", "Дневная цель")) {
                        ValueStepper(value: $store.settings.waterGoal, range: 4...16) { Words.glasses($0) }
                    }
                    SettingsRow(title: tr("Today", "Сьогодні", "Сегодня"), divider: false) {
                        HStack(spacing: 8) {
                            WaterDrops(count: store.today.water, goal: store.settings.waterGoal)
                                .frame(width: 120)
                            Text("\(store.today.water)").monospacedDigit().foregroundStyle(.secondary)
                            Button { store.logWater(-1) } label: { Image(systemName: "minus.circle.fill") }
                                .buttonStyle(.borderless)
                                .disabled(store.today.water == 0)
                            Button { store.logWater() } label: { Image(systemName: "plus.circle.fill") }
                                .buttonStyle(.borderless)
                        }
                    }
                }
                SettingsGroup(title: tr("Weekly summary", "Підсумок тижня", "Итог недели"),
                              footer: tr("A card with your week, ready to save or post. It opens on Friday after work.",
                                         "Картка з твоїм тижнем, яку можна зберегти чи запостити. Відкривається в п'ятницю після роботи.",
                                         "Карточка с твоей неделей, которую можно сохранить или запостить. Открывается в пятницу после работы.")) {
                    SettingsToggle(title: tr("Show it every Friday", "Показувати щоп'ятниці", "Показывать каждую пятницу"),
                                   isOn: $store.settings.weeklySummary)
                    SettingsRow(title: tr("This week so far", "Цей тиждень", "Эта неделя"), divider: false) {
                        Button(tr("Open the card", "Відкрити картку", "Открыть карточку")) { actions.showWeekly() }
                            .buttonStyle(PillButtonStyle(compact: true))
                            .fixedSize()
                    }
                }
            }
            VStack(spacing: 16) {
                SettingsGroup(title: tr("Eye breaks", "Перерви для очей", "Перерывы для глаз"),
                              footer: tr("The 20-20-20 rule: regularly look about 6 metres away for 20 seconds. A small card counts down, without sound, and never during a call.",
                                         "Правило 20-20-20: регулярно дивись приблизно на 6 метрів удалину 20 секунд. Маленька картка рахує час, без звуку і ніколи під час дзвінка.",
                                         "Правило 20-20-20: регулярно смотри примерно на 6 метров вдаль 20 секунд. Маленькая карточка считает время, без звука и никогда во время звонка.")) {
                    SettingsToggle(title: tr("Remind me to rest my eyes", "Нагадувати дати очам відпочити", "Напоминать дать глазам отдохнуть"),
                                   isOn: $store.settings.eyeBreaksEnabled)
                    SettingsRow(title: tr("How often", "Як часто", "Как часто")) {
                        Picker("", selection: $store.settings.eyeBreakMinutes) {
                            ForEach([20, 30, 45, 60], id: \.self) { Text(Clock.everyLabel($0)).tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    .disabled(!store.settings.eyeBreaksEnabled)
                    SettingsRow(title: tr("Today", "Сьогодні", "Сегодня"), divider: false) {
                        HStack(spacing: 10) {
                            Text("\(store.today.eyeBreaks) 👀").monospacedDigit().foregroundStyle(.secondary)
                            Button(tr("Try now", "Спробувати", "Попробовать")) { actions.previewEyeBreak() }
                                .buttonStyle(PillButtonStyle(compact: true))
                                .fixedSize()
                        }
                    }
                }
                SettingsGroup(title: tr("Walking pet", "Улюбленець на прогулянці", "Питомец на прогулке")) {
                    SettingsToggle(title: tr("Let the pet walk along the Dock", "Хай улюбленець гуляє над Dock", "Пусть питомец гуляет над Dock"),
                                   subtitle: tr("It strolls, naps after work and hops when it's time to stand up. Click it for a boop.",
                                                "Гуляє, дрімає після роботи й підстрибує, коли час вставати. Клацни — і він зрадіє.",
                                                "Гуляет, дремлет после работы и подпрыгивает, когда пора вставать. Кликни — и он обрадуется."),
                                   isOn: $store.settings.petWalks, divider: false)
                }
            }
        }
    }
}

/// Water progress as a row of little drops.
struct WaterDrops: View {
    let count: Int
    let goal: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<max(1, goal), id: \.self) { i in
                Capsule()
                    .fill(i < count ? Color(hex: "#4FA3E0") : Color.primary.opacity(0.1))
                    .frame(height: 7)
            }
        }
    }
}
