import SwiftUI

/// Callbacks the SwiftUI layer uses to reach AppKit-owned windows.
@MainActor
final class AppActions {
    var startWarmUp: () -> Void = {}
    var openSettings: () -> Void = {}
    var quit: () -> Void = {}
    var showHeldNow: () -> Void = {}
    var previewStandup: () -> Void = {}
    var previewReminder: (CustomReminder) -> Void = { _ in }
    var petTapped: () -> Void = {}
    var pause: (Int) -> Void = { _ in }
    var pauseUntilTomorrow: () -> Void = {}
    var resume: () -> Void = {}
}

struct PopoverView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var scheduler: Scheduler
    let actions: AppActions

    var body: some View {
        let now = scheduler.now
        VStack(spacing: 10) {
            hero(now: now)
            if let toast = store.toast {
                ToastBanner(toast: toast) { store.toast = nil }
            }
            notices(now: now)
            nextCard(now: now)
            todayCard
            if !scheduler.upcoming.isEmpty { upcomingCard }
            footer(now: now)
        }
        .padding(14)
        .frame(width: 340)
        .animation(.easeInOut(duration: 0.2), value: store.toast)
    }

    // MARK: Hero

    @ViewBuilder
    private func hero(now: Date) -> some View {
        let s = store.settings
        let mood = scheduler.petMood(at: now)
        let info = PetState.levelInfo(xp: store.pet.xp)
        VStack(spacing: 2) {
            SpeechBubble(text: PetTalk.line(store: store, scheduler: scheduler, now: now))
                .frame(maxWidth: 290)
            if s.petEnabled {
                PetView(look: store.petLook, mood: mood)
                    .frame(width: 124, height: 124)
                    .contentShape(Circle())
                    .onTapGesture { actions.petTapped() }
                    .help("Pet \(s.petName)!")
                HStack(spacing: 6) {
                    Text(s.petName).font(.system(size: 15, weight: .bold, design: .rounded))
                    LevelBadge(level: info.level, tint: store.accent)
                }
            } else {
                Image(systemName: "figure.stand")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(store.accent)
                    .frame(height: 110)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [store.petColor.opacity(0.38), store.petColor.opacity(0.1)],
                                     startPoint: .top, endPoint: .bottom))
        )
    }

    // MARK: Notices

    @ViewBuilder
    private func notices(now: Date) -> some View {
        if let reason = scheduler.holdReason, !scheduler.queue.isEmpty {
            Card {
                HStack(spacing: 10) {
                    Image(systemName: reason == "camera" ? "video.fill" : "mic.fill")
                        .foregroundStyle(.orange)
                    Text("Holding a reminder while your \(reason) is in use.")
                        .font(.system(size: 12))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Show now") { actions.showHeldNow() }
                        .buttonStyle(PillButtonStyle(compact: true))
                }
            }
        }
        if scheduler.isPaused(now), let until = store.runtime.pausedUntil {
            Card {
                HStack(spacing: 10) {
                    Image(systemName: "pause.circle.fill").foregroundStyle(.secondary)
                    Text("Paused until \(Clock.time(until))")
                        .font(.system(size: 12.5, weight: .medium))
                    Spacer(minLength: 0)
                    Button("Resume") { actions.resume() }
                        .buttonStyle(PillButtonStyle(compact: true))
                }
            }
        }
    }

    // MARK: Next stand-up

    private func nextCard(now: Date) -> some View {
        let interval = Double(max(15, store.settings.intervalMinutes) * 60)
        let remaining = scheduler.nextStandup.map { $0.timeIntervalSince(now) }
        let progress = remaining.map { 1 - min(1, max(0, $0 / interval)) } ?? 0

        let title: String
        let value: String
        let detail: String
        if scheduler.active?.isStandup == true {
            title = "Stand-up"
            value = "It's time!"
            detail = "Your pet is waving at you"
        } else if let next = scheduler.nextStandup, let remaining {
            title = "Next stand-up"
            value = remaining > 0 ? Clock.relative(remaining) : "any second"
            let sameDay = Clock.calendar.isDate(next, inSameDayAs: now)
            detail = sameDay ? "at \(Clock.time(next))" : next.formatted(.dateTime.weekday(.wide).hour().minute())
        } else {
            title = "Next stand-up"
            value = "Nothing scheduled"
            detail = "Pick work days in Settings"
        }

        return Card {
            HStack(spacing: 12) {
                ZStack {
                    ProgressRing(progress: progress, lineWidth: 5, tint: store.accent)
                    Image(systemName: "figure.stand")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(store.accent)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    Text(value).font(.system(size: 17, weight: .bold, design: .rounded)).monospacedDigit()
                    Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button {
                    actions.startWarmUp()
                } label: {
                    Label("Stand now", systemImage: "figure.cooldown")
                }
                .buttonStyle(PillButtonStyle(prominent: true, tint: store.accent, compact: true))
                .fixedSize()
            }
        }
    }

    // MARK: Today

    private var todayCard: some View {
        let today = store.today
        let goal = max(1, store.settings.dailyGoal)
        let info = PetState.levelInfo(xp: store.pet.xp)
        let streak = store.currentStreak()
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                StatTile(title: "Today", value: "\(today.standupsDone)/\(goal)")
                StatTile(title: "Streak", value: streak > 0 ? "\(streak) 🔥" : "0")
                StatTile(title: "Mood", value: "\(moodEmoji) \(Int(store.pet.happiness))%")
            }
            Card {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 3) {
                        ForEach(0..<goal, id: \.self) { i in
                            Capsule()
                                .fill(i < today.standupsDone ? AnyShapeStyle(store.accent.gradient) : AnyShapeStyle(Color.primary.opacity(0.1)))
                                .frame(height: 7)
                        }
                    }
                    HStack {
                        Text("Level \(info.level)").font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        Spacer()
                        Text("\(info.into) / \(info.needed) XP").font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
                    }
                    ProgressView(value: Double(info.into), total: Double(info.needed))
                        .tint(store.accent)
                        .controlSize(.small)
                }
            }
        }
    }

    private var moodEmoji: String {
        switch store.pet.happiness {
        case 80...: return "🥰"
        case 55..<80: return "😊"
        case 30..<55: return "😐"
        default: return "🥺"
        }
    }

    // MARK: Upcoming extras

    private var upcomingCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Text("Coming up").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                ForEach(scheduler.upcoming) { item in
                    HStack(spacing: 8) {
                        Text(item.emoji)
                        Text(item.title).font(.system(size: 12.5)).lineLimit(1)
                        if item.isSnoozed {
                            Text("snoozed")
                                .font(.system(size: 9.5, weight: .semibold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Capsule().fill(Color.orange.opacity(0.2)))
                        }
                        Spacer()
                        Text(Clock.time(item.date)).font(.system(size: 12)).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
            }
        }
    }

    // MARK: Footer

    private func footer(now: Date) -> some View {
        HStack(spacing: 12) {
            Toggle("Sound", isOn: $store.settings.soundEnabled)
                .toggleStyle(.checkbox)
            Toggle("Pet", isOn: $store.settings.petEnabled)
                .toggleStyle(.checkbox)
            Spacer()
            Menu {
                if scheduler.isPaused(now) {
                    Button("Resume now") { actions.resume() }
                    Divider()
                }
                Button("Pause 30 minutes") { actions.pause(30) }
                Button("Pause 1 hour") { actions.pause(60) }
                Button("Pause 2 hours") { actions.pause(120) }
                Button("Pause until tomorrow") { actions.pauseUntilTomorrow() }
            } label: {
                Image(systemName: scheduler.isPaused(now) ? "pause.circle.fill" : "pause.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Pause reminders")
            Button { actions.openSettings() } label: { Image(systemName: "gearshape") }
                .buttonStyle(.borderless)
                .help("Settings")
            Button { actions.quit() } label: { Image(systemName: "power") }
                .buttonStyle(.borderless)
                .help("Quit StandUp Pal")
        }
        .font(.system(size: 12.5))
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }
}
