import SwiftUI

enum SettingsTab: String, CaseIterable {
    case general, reminders, warmUp, pet, stats, about
}

final class SettingsNavigation: ObservableObject {
    @Published var tab: SettingsTab = .general
}

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject var navigation: SettingsNavigation
    let actions: AppActions

    var body: some View {
        TabView(selection: $navigation.tab) {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            RemindersSettings(actions: actions)
                .tabItem { Label("Reminders", systemImage: "bell.badge") }
                .tag(SettingsTab.reminders)
            WarmUpSettings()
                .tabItem { Label("Warm-up", systemImage: "figure.cooldown") }
                .tag(SettingsTab.warmUp)
            PetSettings()
                .tabItem { Label("Pet", systemImage: "pawprint") }
                .tag(SettingsTab.pet)
            StatsSettings()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
                .tag(SettingsTab.stats)
            AboutSettings(actions: actions)
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .padding(.top, 8)
        .frame(width: 640, height: 600)
        .tint(store.accent)
    }
}

struct GeneralSettings: View {
    @EnvironmentObject var store: AppStore
    @ViewState private var loginEnabled = LoginItem.isEnabled
    @ViewState private var loginMessage: String?

    var body: some View {
        Form {
            Section("Working hours") {
                DatePicker("Start", selection: minuteBinding($store.settings.workStartMinute), displayedComponents: .hourAndMinute)
                DatePicker("End", selection: minuteBinding($store.settings.workEndMinute), displayedComponents: .hourAndMinute)
                LabeledContent("Work days") {
                    WeekdayPicker(selection: $store.settings.workDays, tint: store.accent)
                }
            }

            Section {
                Picker("Remind me every", selection: $store.settings.intervalMinutes) {
                    ForEach([30, 45, 60, 90, 120], id: \.self) { Text(Clock.durationLabel($0)).tag($0) }
                }
                Stepper(value: $store.settings.leadMinutes, in: 0...15) {
                    LabeledContent("Minutes before the slot ends", value: "\(store.settings.leadMinutes) min")
                }
                Picker("Snooze for", selection: $store.settings.snoozeMinutes) {
                    ForEach([5, 10, 15], id: \.self) { Text("\($0) min").tag($0) }
                }
                Stepper(value: $store.settings.dailyGoal, in: 1...16) {
                    LabeledContent("Daily goal", value: "\(store.settings.dailyGoal) stand-ups")
                }
                Toggle("Quiet lunch break", isOn: $store.settings.lunchEnabled)
                if store.settings.lunchEnabled {
                    DatePicker("Lunch starts", selection: minuteBinding($store.settings.lunchStartMinute), displayedComponents: .hourAndMinute)
                    DatePicker("Lunch ends", selection: minuteBinding($store.settings.lunchEndMinute), displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Stand-up reminders")
            } footer: {
                Text(schedulePreview).foregroundStyle(.secondary)
            }

            Section("Smart behaviour") {
                Toggle("Skip the reminder if I've already been away for 5+ minutes", isOn: $store.settings.smartAway)
                Toggle("Hold reminders while my camera or microphone is in use", isOn: $store.settings.holdDuringCalls)
                Toggle("Gentle second nudge after 3 minutes", isOn: $store.settings.renudge)
            }

            Section("Sound") {
                Toggle("Play sounds", isOn: $store.settings.soundEnabled)
                Picker("Reminder sound", selection: $store.settings.soundChoice) {
                    ForEach(SoundChoice.allCases) { Text($0.label).tag($0) }
                }
                .disabled(!store.settings.soundEnabled)
                HStack(spacing: 8) {
                    Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                    Slider(value: $store.settings.volume, in: 0.05...1)
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                    Button("Preview") {
                        SoundPlayer.shared.preview(store.settings.soundChoice, volume: store.settings.volume)
                    }
                }
                .disabled(!store.settings.soundEnabled)
            }

            Section("Menu bar & startup") {
                Toggle("Show countdown next to the icon", isOn: $store.settings.showCountdown)
                Toggle("Launch at login", isOn: Binding(get: { loginEnabled }, set: setLogin))
                if let loginMessage {
                    HStack {
                        Text(loginMessage).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Login Items") { LoginItem.openSystemSettings() }
                            .controlSize(.small)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: store.settings.soundChoice) { _, choice in
            SoundPlayer.shared.preview(choice, volume: store.settings.volume)
        }
        .onAppear { refreshLogin() }
    }

    private var schedulePreview: String {
        let minutes = Scheduler.standupMinutes(store.settings)
        guard !minutes.isEmpty else { return "No stand-ups fit inside your working hours." }
        let shown = minutes.prefix(4).map { Clock.time(minute: $0) }.joined(separator: ", ")
        let more = minutes.count > 4 ? ", … \(Clock.time(minute: minutes.last!))" : ""
        return "Stand-ups on work days: \(shown)\(more) (\(minutes.count) a day)."
    }

    private func setLogin(_ enabled: Bool) {
        do {
            try LoginItem.set(enabled)
            loginMessage = nil
        } catch {
            loginMessage = "macOS said no: \(error.localizedDescription)"
        }
        refreshLogin()
    }

    private func refreshLogin() {
        loginEnabled = LoginItem.isEnabled
        if LoginItem.needsApproval {
            loginMessage = "Approve StandUp Pal in System Settings › General › Login Items."
        }
    }
}

struct AboutSettings: View {
    @EnvironmentObject var store: AppStore
    let actions: AppActions

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            PetView(look: store.petLook, mood: .happy)
                .frame(width: 130, height: 130)
            Text("StandUp Pal")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                .foregroundStyle(.secondary)
            Text("A tiny friend that gets you out of your chair before every hour ends, guides a short warm-up, and grows with every stretch.")
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Text("Everything stays on this Mac: no accounts, no network, no tracking.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button("Preview stand-up") { actions.previewStandup() }
                if let first = store.reminders.first {
                    Button("Preview extra reminder") { actions.previewReminder(first) }
                }
                Button("Start a warm-up") { actions.startWarmUp() }
            }
            .buttonStyle(PillButtonStyle())
            .padding(.top, 6)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}
