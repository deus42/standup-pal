import SwiftUI

enum SettingsTab: String, CaseIterable {
    case general, reminders, warmUp, pet, gear, stats, about

    var title: String {
        switch self {
        case .general: return tr("General", "Загальні", "Основные")
        case .reminders: return tr("Reminders", "Нагадування", "Напоминания")
        case .warmUp: return tr("Warm-up", "Розминка", "Разминка")
        case .pet: return tr("Pet", "Улюбленець", "Питомец")
        case .gear: return tr("Gear", "Спорядження", "Снаряжение")
        case .stats: return tr("Stats", "Статистика", "Статистика")
        case .about: return tr("About", "Про програму", "О программе")
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .reminders: return "bell.badge.fill"
        case .warmUp: return "figure.cooldown"
        case .pet: return "pawprint.fill"
        case .gear: return "dumbbell.fill"
        case .stats: return "chart.bar.fill"
        case .about: return "info.circle.fill"
        }
    }
}

final class SettingsNavigation: ObservableObject {
    @Published var tab: SettingsTab = .general
}

/// The settings window. Every tab is laid out to fit without scrolling; the window
/// resizes to whichever tab is showing (see `onHeight`).
struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject var navigation: SettingsNavigation
    let actions: AppActions
    var onHeight: (CGFloat) -> Void = { _ in }

    static let width: CGFloat = 720

    var body: some View {
        VStack(spacing: 0) {
            tabBar
                .id(store.settings.language)
            Divider()
            content
                .id(store.settings.language)
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 22)
        }
        .frame(width: Self.width)
        .fixedSize(horizontal: false, vertical: true)
        .background(GeometryReader { geo in
            Color.clear.preference(key: HeightKey.self, value: geo.size.height)
        })
        .onPreferenceChange(HeightKey.self) { height in onHeight(height) }
        .frame(maxHeight: .infinity, alignment: .top)
        .tint(store.accent)
        .environment(\.locale, L10n.locale)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                let selected = navigation.tab == tab
                Button { navigation.tab = tab } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 34, height: 28)
                            .foregroundStyle(selected ? Color.white : Color.secondary)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selected ? AnyShapeStyle(store.accent.gradient) : AnyShapeStyle(Color.primary.opacity(0.06))))
                        Text(tab.title)
                            .font(.system(size: 11, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? Color.primary : Color.secondary)
                            .lineLimit(1)
                    }
                    .frame(width: 92)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch navigation.tab {
        case .general: GeneralSettings()
        case .reminders: RemindersSettings(actions: actions)
        case .warmUp: WarmUpSettings()
        case .pet: PetSettings()
        case .gear: GearSettings()
        case .stats: StatsSettings()
        case .about: AboutSettings(actions: actions)
        }
    }
}

/// A compact hh:mm field bound to "minutes since midnight".
struct TimeField: View {
    @Binding var minutes: Int

    var body: some View {
        DatePicker("", selection: minuteBinding($minutes), displayedComponents: .hourAndMinute)
            .labelsHidden()
            .datePickerStyle(.field)
            .fixedSize()
    }
}

struct GeneralSettings: View {
    @EnvironmentObject var store: AppStore
    @ViewState private var loginEnabled = LoginItem.isEnabled
    @ViewState private var loginMessage: String?

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(spacing: 16) {
                workingHours
                reminders
            }
            VStack(spacing: 16) {
                SettingsGroup(title: tr("Language", "Мова", "Язык")) {
                    SettingsRow(title: tr("App language", "Мова застосунку", "Язык приложения"), divider: false) {
                        Picker("", selection: $store.settings.language) {
                            ForEach(AppLanguage.allCases) { Text($0.nativeName).tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }
                smartBehaviour
                sound
                startup
            }
        }
        .onChange(of: store.settings.soundChoice) { _, choice in
            SoundPlayer.shared.preview(choice, volume: store.settings.volume)
        }
        .onAppear { refreshLogin() }
    }

    private var workingHours: some View {
        SettingsGroup(title: tr("Working hours", "Робочий час", "Рабочее время")) {
            SettingsRow(title: tr("Start", "Початок", "Начало")) { TimeField(minutes: $store.settings.workStartMinute) }
            SettingsRow(title: tr("End", "Кінець", "Конец")) { TimeField(minutes: $store.settings.workEndMinute) }
            VStack(alignment: .leading, spacing: 8) {
                Text(tr("Work days", "Робочі дні", "Рабочие дни")).font(.system(size: 13))
                WeekdayPicker(selection: $store.settings.workDays, tint: store.accent, dayWidth: 39)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var reminders: some View {
        SettingsGroup(title: tr("Stand-up reminders", "Нагадування встати", "Напоминания встать"), footer: schedulePreview) {
            SettingsRow(title: tr("Remind me", "Нагадувати", "Напоминать")) {
                Picker("", selection: $store.settings.intervalMinutes) {
                    ForEach([30, 45, 60, 90, 120], id: \.self) { Text(Clock.everyLabel($0)).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            SettingsRow(title: tr("Remind early by", "Нагадати заздалегідь за", "Напомнить заранее за")) {
                ValueStepper(value: $store.settings.leadMinutes, range: 0...15) { Words.minutes($0) }
            }
            SettingsRow(title: tr("Snooze for", "Відкладати на", "Откладывать на")) {
                Picker("", selection: $store.settings.snoozeMinutes) {
                    ForEach([5, 10, 15], id: \.self) { Text(Words.minutes($0)).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            SettingsRow(title: tr("Daily goal", "Денна мета", "Дневная цель")) {
                ValueStepper(value: $store.settings.dailyGoal, range: 1...16) { Words.breaks($0) }
            }
            SettingsToggle(title: tr("Quiet lunch break", "Тиха обідня перерва", "Тихий обеденный перерыв"),
                           isOn: $store.settings.lunchEnabled, divider: store.settings.lunchEnabled)
            if store.settings.lunchEnabled {
                SettingsRow(title: tr("Lunch", "Обід", "Обед"), divider: false) {
                    HStack(spacing: 6) {
                        TimeField(minutes: $store.settings.lunchStartMinute)
                        Text("–").foregroundStyle(.secondary)
                        TimeField(minutes: $store.settings.lunchEndMinute)
                    }
                }
            }
        }
    }

    private var smartBehaviour: some View {
        SettingsGroup(title: tr("Smart behaviour", "Розумна поведінка", "Умное поведение")) {
            SettingsToggle(title: tr("Skip if I'm already away", "Пропускати, якщо мене немає", "Пропускать, если меня нет"),
                           subtitle: tr("5+ min without keyboard or mouse counts", "5+ хв без клавіатури й миші зараховуються",
                                        "5+ мин без клавиатуры и мыши засчитываются"),
                           isOn: $store.settings.smartAway)
            SettingsToggle(title: tr("Wait while I'm on a call", "Чекати, поки я на дзвінку", "Ждать, пока я на звонке"),
                           subtitle: tr("Camera or microphone in use", "Увімкнена камера чи мікрофон", "Включена камера или микрофон"),
                           isOn: $store.settings.holdDuringCalls)
            SettingsToggle(title: tr("Gentle second nudge", "Друге м'яке нагадування", "Второе мягкое напоминание"),
                           subtitle: tr("After 3 minutes", "Через 3 хвилини", "Через 3 минуты"),
                           isOn: $store.settings.renudge, divider: false)
        }
    }

    private var sound: some View {
        SettingsGroup(title: tr("Sound", "Звук", "Звук")) {
            SettingsToggle(title: tr("Play sounds", "Відтворювати звуки", "Воспроизводить звуки"), isOn: $store.settings.soundEnabled)
            SettingsRow(title: tr("Reminder sound", "Звук нагадування", "Звук напоминания")) {
                Picker("", selection: $store.settings.soundChoice) {
                    ForEach(SoundChoice.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            .disabled(!store.settings.soundEnabled)
            SettingsRow(title: tr("Volume", "Гучність", "Громкость"), divider: false) {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.fill").font(.system(size: 10)).foregroundStyle(.secondary)
                    Slider(value: $store.settings.volume, in: 0.05...1).frame(width: 100).controlSize(.small)
                    Button {
                        SoundPlayer.shared.preview(store.settings.soundChoice, volume: store.settings.volume)
                    } label: {
                        Image(systemName: "play.circle.fill").font(.system(size: 16))
                    }
                    .buttonStyle(.borderless)
                    .help(tr("Preview", "Прослухати", "Прослушать"))
                }
            }
            .disabled(!store.settings.soundEnabled)
        }
    }

    private var startup: some View {
        SettingsGroup(title: tr("Menu bar & startup", "Рядок меню й запуск", "Строка меню и запуск")) {
            SettingsToggle(title: tr("Countdown next to the icon", "Відлік біля значка", "Отсчёт рядом со значком"),
                           isOn: $store.settings.showCountdown)
            SettingsToggle(title: tr("Launch at login", "Запускати під час входу", "Запускать при входе"),
                           isOn: Binding(get: { loginEnabled }, set: setLogin), divider: loginMessage != nil)
            if let loginMessage {
                HStack(spacing: 8) {
                    Text(loginMessage).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button(tr("Open", "Відкрити", "Открыть")) { LoginItem.openSystemSettings() }
                        .controlSize(.small)
                }
                .padding(12)
            }
        }
    }

    private var schedulePreview: String {
        let minutes = Scheduler.standupMinutes(store.settings)
        guard !minutes.isEmpty else {
            return tr("No stand-ups fit inside your working hours.", "Жодна перерва не вміщається в робочий час.",
                      "Ни один перерыв не помещается в рабочее время.")
        }
        let shown = minutes.prefix(4).map { Clock.time(minute: $0) }.joined(separator: ", ")
        let more = minutes.count > 4 ? ", … \(Clock.time(minute: minutes.last!))" : ""
        let count = Words.breaks(minutes.count)
        return tr("On work days: \(shown)\(more) (\(count) a day).", "У робочі дні: \(shown)\(more) — \(count) на день.",
                  "В рабочие дни: \(shown)\(more) — \(count) в день.")
    }

    private func setLogin(_ enabled: Bool) {
        do {
            try LoginItem.set(enabled)
            loginMessage = nil
        } catch {
            let reason = error.localizedDescription
            loginMessage = tr("macOS said no: \(reason)", "macOS відмовляє: \(reason)", "macOS отказывает: \(reason)")
        }
        refreshLogin()
    }

    private func refreshLogin() {
        loginEnabled = LoginItem.isEnabled
        if LoginItem.needsApproval {
            loginMessage = tr("Approve StandUp Pal in System Settings › General › Login Items.",
                              "Дозволь StandUp Pal у Системних параметрах › Загальні › Об'єкти входу.",
                              "Разреши StandUp Pal в Системных настройках › Основные › Объекты входа.")
        }
    }
}

struct AboutSettings: View {
    @EnvironmentObject var store: AppStore
    let actions: AppActions

    var body: some View {
        VStack(spacing: 12) {
            PetView(look: store.petLook, mood: .happy)
                .frame(width: 120, height: 120)
            Text("StandUp Pal")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
            Text(tr("Version \(version)", "Версія \(version)", "Версия \(version)"))
                .foregroundStyle(.secondary)
            Text(tr("A tiny fitness pet that gets you out of your chair before every hour ends, guides a short warm-up, and grows with every stretch.",
                    "Маленький фітнес-улюбленець, що піднімає тебе зі стільця перед кінцем кожної години, проводить коротку розминку й росте з кожною розтяжкою.",
                    "Маленький фитнес-питомец, который поднимает тебя со стула перед концом каждого часа, проводит короткую разминку и растёт с каждой растяжкой."))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 460)
            HStack(spacing: 2) {
                ForEach(PetSpecies.allCases) { species in
                    PetView(look: lookFor(species), mood: .idle, effects: false)
                        .frame(width: 40, height: 40)
                        .help("\(species.label) · \(species.role)")
                }
            }
            .padding(.vertical, 4)
            Text(tr("Everything stays on this Mac: no accounts, no network, no tracking.",
                    "Усе лишається на цьому Mac: без акаунтів, мережі й стеження.",
                    "Всё остаётся на этом Mac: без аккаунтов, сети и слежки."))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button(tr("Preview stand-up", "Показати перерву", "Показать перерыв")) { actions.previewStandup() }
                if let first = store.reminders.first {
                    Button(tr("Preview extra reminder", "Показати нагадування", "Показать напоминание")) { actions.previewReminder(first) }
                }
                Button(tr("Start a warm-up", "Почати розминку", "Начать разминку")) { actions.startWarmUp() }
            }
            .buttonStyle(PillButtonStyle())
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    /// Each species in a palette of its own, wearing the user's head gear.
    private func lookFor(_ species: PetSpecies) -> PetLook {
        let palettes = PetPalette.all
        let index = PetSpecies.allCases.firstIndex(of: species) ?? 0
        let palette = palettes[(index * 5 + 3) % palettes.count]
        return PetLook(species: species, color: RGB(hex: palette.body), belly: RGB(hex: palette.belly), head: .sweatband)
    }
}
