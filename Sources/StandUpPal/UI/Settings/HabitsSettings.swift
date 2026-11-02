import SwiftUI

/// Small healthy habits around the stand-ups: water, eye breaks, the weekly card, the
/// walking pet and the pet's day (outfits and bedtime).
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
                SettingsGroup(title: tr("Walking pet", "Улюбленець на прогулянці", "Питомец на прогулке")) {
                    SettingsToggle(title: tr("Let the pet walk along the Dock", "Хай улюбленець гуляє над Dock", "Пусть питомец гуляет над Dock"),
                                   subtitle: tr("It strolls, sleeps after bedtime and hops when it's time to stand up. Click it for a boop.",
                                                "Гуляє, спить після відбою й підстрибує, коли час вставати. Клацни — і він зрадіє.",
                                                "Гуляет, спит после отбоя и подпрыгивает, когда пора вставать. Кликни — и он обрадуется."),
                                   isOn: $store.settings.petWalks, divider: false)
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
                SettingsGroup(title: tr("Pet's day", "День улюбленця", "День питомца"),
                              footer: tr("After bedtime the pet sleeps, and while you're still at the Mac it asks you to step away, every half hour.",
                                         "Після відбою улюбленець спить, а поки ти за компом, щопівгодини проситиме від нього відійти.",
                                         "После отбоя питомец спит, а пока ты за компом, каждые полчаса будет просить от него отойти.")) {
                    SettingsToggle(title: tr("Dress for the time of day", "Одяг за часом доби", "Одежда по времени суток"),
                                   subtitle: tr("A tie at work, pyjamas and coffee at home", "Краватка на роботі, піжама й кава вдома",
                                                "Галстук на работе, пижама и кофе дома"),
                                   isOn: $store.settings.dayOutfits)
                    SettingsRow(title: tr("Bedtime", "Відбій", "Отбой")) {
                        Picker("", selection: $store.settings.bedtimeMinute) {
                            ForEach(bedtimeChoices, id: \.self) { Text(Clock.time(minute: $0)).tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    SettingsToggle(title: tr("Send me to bed too", "Відправляти спати й мене", "Отправлять спать и меня"),
                                   isOn: $store.settings.bedtimeNudge, divider: false)
                }
            }
        }
    }

    private var bedtimeChoices: [Int] {
        let current = store.settings.bedtimeMinute
        return DayRhythm.bedtimeChoices.contains(current) ? DayRhythm.bedtimeChoices : (DayRhythm.bedtimeChoices + [current]).sorted()
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
