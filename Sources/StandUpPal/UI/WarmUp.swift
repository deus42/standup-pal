import AppKit
import AVFoundation
import SwiftUI

/// Runs one guided warm-up: optional get-ready countdown, then each exercise on a timer.
@MainActor
final class WarmUpSession: ObservableObject {
    enum Phase: Equatable {
        case getReady, exercising, finished
    }

    let routine: [Exercise]
    let occurrence: Occurrence?

    @Published private(set) var phase: Phase
    @Published private(set) var index = 0
    @Published private(set) var remaining: Double
    @Published private(set) var getReadyRemaining: Double = 3
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var completedFully = false
    @Published var rewardXP = 0
    @Published var isPaused = false

    var onComplete: ((WarmUpSession) -> Void)?

    private var timer: Timer?
    private var lastTick = Date()
    private let speech = AVSpeechSynthesizer()

    init(routine: [Exercise], occurrence: Occurrence?, getReady: Bool) {
        self.routine = routine.isEmpty ? Array(ExerciseLibrary.builtIn.prefix(1)) : routine
        self.occurrence = occurrence
        phase = getReady ? .getReady : .exercising
        remaining = Double(self.routine[0].seconds)
    }

    var current: Exercise { routine[min(index, routine.count - 1)] }
    var next: Exercise? { index + 1 < routine.count ? routine[index + 1] : nil }
    var stepProgress: Double { 1 - remaining / Double(max(1, current.seconds)) }
    var totalSeconds: Int { routine.reduce(0) { $0 + $1.seconds } }

    func start() {
        lastTick = Date()
        let t = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        if phase == .exercising { announce() } else { speak("Get ready") }
    }

    private func tick() {
        let now = Date()
        let dt = now.timeIntervalSince(lastTick)
        lastTick = now
        guard !isPaused else { return }
        switch phase {
        case .getReady:
            let before = Int(getReadyRemaining.rounded(.up))
            getReadyRemaining -= dt
            if getReadyRemaining <= 0 {
                phase = .exercising
                SoundPlayer.shared.play(.tick)
                announce()
            } else if Int(getReadyRemaining.rounded(.up)) != before {
                SoundPlayer.shared.play(.tick)
            }
        case .exercising:
            remaining -= dt
            elapsed += dt
            if remaining <= 0 { advance() }
        case .finished:
            break
        }
    }

    func skip() {
        if phase == .getReady {
            getReadyRemaining = 0
            return
        }
        advance()
    }

    private func advance() {
        if index + 1 < routine.count {
            index += 1
            remaining = Double(current.seconds)
            SoundPlayer.shared.play(.tick)
            announce()
        } else {
            finish()
        }
    }

    /// Ends the session and records it. Counts as "full" when most of it was done.
    func finish() {
        guard phase != .finished else { return }
        completedFully = elapsed >= Double(totalSeconds) * 0.6
        phase = .finished
        stopTimer()
        SoundPlayer.shared.play(.success)
        speak(completedFully ? "Great job!" : "Nice work!")
        onComplete?(self)
    }

    func stop() {
        stopTimer()
        speech.stopSpeaking(at: .immediate)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func announce() {
        speak(current.name)
    }

    private func speak(_ text: String) {
        let s = AppStore.shared.settings
        guard s.speakExercises else { return }
        speech.stopSpeaking(at: .word)
        let utterance = AVSpeechUtterance(string: text)
        utterance.volume = Float(max(0.2, s.volume))
        speech.speak(utterance)
    }
}

@MainActor
final class WarmUpController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var session: WarmUpSession?
    var onClose: (() -> Void)?

    var isOpen: Bool { window != nil }
    var contentView: NSView? { window?.contentView }

    func finishNow() {
        session?.finish()
    }

    func open(occurrence: Occurrence?) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let store = AppStore.shared
        let routine = ExerciseLibrary.routine(totalSeconds: store.settings.warmUpLength.rawValue, settings: store.settings)
        let session = WarmUpSession(routine: routine, occurrence: occurrence, getReady: store.settings.getReadyCountdown)
        session.onComplete = { session in
            session.rewardXP = Scheduler.shared.completeWarmUp(for: session.occurrence, seconds: session.elapsed,
                                                                full: session.completedFully)
        }

        let view = WarmUpView(session: session, onClose: { [weak self, weak session] in
            // Ignore late auto-close timers from an earlier session.
            guard let self, let session, self.session === session else { return }
            self.close()
        })
        .environmentObject(store)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "Warm-up"
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        self.window = window
        self.session = session
        Scheduler.shared.beginWarmUp(from: occurrence)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        session.start()
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        if let session {
            session.stop()
            if session.phase != .finished {
                // Closed early: still credit real effort.
                if session.elapsed >= 45 {
                    Scheduler.shared.completeWarmUp(for: session.occurrence, seconds: session.elapsed, full: false)
                } else if let occ = session.occurrence {
                    Scheduler.shared.resolve(occ, .stoodUp)
                }
            }
        }
        session = nil
        window = nil
        Scheduler.shared.endWarmUp()
        onClose?()
    }
}

struct WarmUpView: View {
    @ObservedObject var session: WarmUpSession
    @EnvironmentObject var store: AppStore
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            LinearGradient(colors: [store.petColor.opacity(0.3), store.petColor.opacity(0)],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
            switch session.phase {
            case .getReady: getReady
            case .exercising: exercising
            case .finished: finished
            }
        }
        .frame(width: 440, height: 600)
    }

    // MARK: Get ready

    private var getReady: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("Stand up & get ready!")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
            ZStack {
                ProgressRing(progress: 1 - session.getReadyRemaining / 3, lineWidth: 10, tint: store.accent)
                Text("\(max(1, Int(session.getReadyRemaining.rounded(.up))))")
                    .font(.system(size: 76, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                    .animation(.snappy, value: Int(session.getReadyRemaining.rounded(.up)))
            }
            .frame(width: 170, height: 170)
            if store.settings.petEnabled {
                PetView(look: store.petLook, mood: .happy).frame(width: 110, height: 110)
            }
            Text("First up: \(session.current.emoji) \(session.current.name)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Skip countdown") { session.skip() }
                .buttonStyle(PillButtonStyle(compact: true))
                .padding(.bottom, 24)
        }
        .padding(.top, 20)
    }

    // MARK: Exercising

    private var exercising: some View {
        let exercise = session.current
        return VStack(spacing: 14) {
            HStack {
                Text("Warm-up").font(.system(size: 14, weight: .bold, design: .rounded))
                Spacer()
                Text("\(session.index + 1) of \(session.routine.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            HStack(spacing: 4) {
                ForEach(session.routine.indices, id: \.self) { i in
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.primary.opacity(0.1))
                            Capsule().fill(store.accent)
                                .frame(width: geo.size.width * segmentFill(i))
                        }
                    }
                    .frame(height: 6)
                }
            }

            ZStack {
                ProgressRing(progress: session.stepProgress, lineWidth: 12, tint: store.accent)
                if store.settings.petEnabled {
                    PetView(look: store.petLook, mood: session.isPaused ? .idle : .exercise)
                        .frame(width: 150, height: 150)
                } else {
                    Text(exercise.emoji).font(.system(size: 84))
                }
                if store.settings.petEnabled {
                    Text(exercise.emoji)
                        .font(.system(size: 30))
                        .padding(9)
                        .background(Circle().fill(Color(nsColor: .windowBackgroundColor)).shadow(color: .black.opacity(0.12), radius: 4, y: 2))
                        .offset(x: 78, y: 78)
                }
            }
            .frame(width: 220, height: 220)
            .padding(.top, 6)

            Text(Clock.mmss(session.remaining))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .opacity(session.isPaused ? 0.45 : 1)

            VStack(spacing: 6) {
                Text(exercise.name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(exercise.instructions)
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 360)
            }
            .id(session.index)
            .transition(.opacity)

            Group {
                if let next = session.next {
                    Text("Up next: \(next.emoji) \(next.name)")
                } else {
                    Text("Last one. Finish strong! 💪")
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button { session.isPaused.toggle() } label: {
                    Label(session.isPaused ? "Resume" : "Pause", systemImage: session.isPaused ? "play.fill" : "pause.fill")
                }
                Button { session.skip() } label: { Label("Skip", systemImage: "forward.fill") }
                Button { endEarly() } label: { Label("End", systemImage: "xmark") }
            }
            .buttonStyle(PillButtonStyle())
        }
        .padding(.horizontal, 28)
        .padding(.top, 34)
        .padding(.bottom, 22)
        .animation(.easeInOut(duration: 0.25), value: session.index)
    }

    private func segmentFill(_ i: Int) -> Double {
        if i < session.index { return 1 }
        if i > session.index { return 0 }
        return max(0, min(1, session.stepProgress))
    }

    private func endEarly() {
        if session.elapsed >= 45 {
            session.finish()
        } else {
            onClose()
        }
    }

    // MARK: Finished

    private var finished: some View {
        let info = PetState.levelInfo(xp: store.pet.xp)
        let streak = store.currentStreak()
        let minutes = Int(session.elapsed) / 60
        let seconds = Int(session.elapsed) % 60
        return ZStack {
            VStack(spacing: 14) {
                Spacer()
                if store.settings.petEnabled {
                    PetView(look: store.petLook, mood: .celebrate).frame(width: 170, height: 170)
                } else {
                    Text("🎉").font(.system(size: 90))
                }
                Text(session.completedFully ? "Warm-up complete!" : "Nice, every bit counts!")
                    .font(.system(size: 25, weight: .heavy, design: .rounded))
                Text("\(minutes > 0 ? "\(minutes) min " : "")\(seconds) s of moving · +\(session.rewardXP) XP")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    StatTile(title: "Level", value: "\(info.level)")
                    StatTile(title: "Today", value: "\(store.today.standupsDone)/\(store.settings.dailyGoal)")
                    StatTile(title: "Streak", value: streak > 0 ? "\(streak) 🔥" : "0")
                }
                .frame(maxWidth: 340)
                if let toast = store.toast {
                    ToastBanner(toast: toast) { store.toast = nil }
                        .frame(maxWidth: 340)
                }
                Spacer()
                Button("Back to work 💪") { onClose() }
                    .buttonStyle(PillButtonStyle(prominent: true, tint: store.accent))
                    .frame(width: 230)
                    .keyboardShortcut(.defaultAction)
                    .padding(.bottom, 26)
            }
            .padding(.horizontal, 28)
            ConfettiView(colors: [store.petColor, .pink, .yellow, .orange, .mint, .purple])
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) { onClose() }
        }
    }
}
