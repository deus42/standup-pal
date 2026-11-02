import SwiftUI

/// Small healthy habits around the stand-ups: eye breaks, the weekly card, the walking
/// pet and the pet's day (outfits and bedtime).
struct HabitsSettings: View {
    @EnvironmentObject var store: AppStore
    let actions: AppActions

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(spacing: 16) {
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
                                   subtitle: tr("Drag it, toss it, double-click for a flip, or stroke it with the cursor. It sleeps in its bed after bedtime.",
                                                "Тягай, підкидай, двічі клацни — сальто, або погладь курсором. Після відбою спить у ліжечку.",
                                                "Таскай, подбрасывай, кликни дважды — сальто, или погладь курсором. После отбоя спит в кроватке."),
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
                              footer: tr("At bedtime the pet shuts its laptop and goes to bed, and while you're still at the Mac it asks you to log off, every half hour.",
                                         "О відбої улюбленець закриває ноутбук і йде спати, а поки ти за компом, щопівгодини проситиме відключатися.",
                                         "В отбой питомец закрывает ноутбук и идёт спать, а пока ты за компом, каждые полчаса будет просить отключаться.")) {
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
                    SettingsRow(title: tr("Send me to bed too", "Відправляти спати й мене", "Отправлять спать и меня"), divider: false) {
                        HStack(spacing: 10) {
                            Button(tr("Show", "Показати", "Показать")) { actions.previewBedtime() }
                                .buttonStyle(PillButtonStyle(compact: true))
                                .fixedSize()
                            Toggle("", isOn: $store.settings.bedtimeNudge)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    private var bedtimeChoices: [Int] {
        let current = store.settings.bedtimeMinute
        return DayRhythm.bedtimeChoices.contains(current) ? DayRhythm.bedtimeChoices : (DayRhythm.bedtimeChoices + [current]).sorted()
    }
}
