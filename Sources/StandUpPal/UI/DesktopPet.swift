import AppKit
import SwiftUI

/// The pet strolling along the top of the Dock. Opt-in, and it keeps to itself: it walks,
/// rests, sleeps outside work hours and hops when it's time to stand up.
@MainActor
final class DesktopPetController {
    private let model = DesktopPetModel()
    private var panel: NSPanel?
    private var timer: Timer?
    private var last = Date()
    private let size = CGSize(width: 104, height: 104)

    init() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.timer?.invalidate() }
        }
        center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if self?.panel != nil { self?.startTimer() } }
        }
    }

    func setEnabled(_ on: Bool) {
        if on { show() } else { hide() }
    }

    private func show() {
        guard panel == nil, let screen = NSScreen.main else { return }
        let view = DesktopPetView(model: model) {
            AppStore.shared.react(.happy, for: 3)
            SoundPlayer.shared.play(.boop)
        }
        .environmentObject(AppStore.shared)
        let panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: size),
                                  styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = NSHostingView(rootView: view)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        let frame = screen.visibleFrame
        model.x = frame.midX - size.width / 2
        panel.setFrameOrigin(NSPoint(x: model.x, y: frame.minY - 8))
        panel.orderFrontRegardless()
        self.panel = panel
        startTimer()
    }

    private func hide() {
        timer?.invalidate()
        timer = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func startTimer() {
        timer?.invalidate()
        last = Date()
        let t = Timer(timeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.step() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func step() {
        guard let panel, let screen = panel.screen ?? NSScreen.main else { return }
        let now = Date()
        let dt = min(0.2, now.timeIntervalSince(last))
        last = now
        let mood = Scheduler.shared.petMood(at: now)
        let frame = screen.visibleFrame
        model.update(dt: dt, mood: mood, minX: frame.minX, maxX: frame.maxX - size.width, now: now)
        panel.setFrameOrigin(NSPoint(x: model.x, y: frame.minY - 8))
    }
}

@MainActor
final class DesktopPetModel: ObservableObject {
    @Published var walking = false
    @Published var facingLeft = false
    @Published var mood: PetMood = .idle
    var x: CGFloat = 0
    private var phaseUntil = Date()
    private let speed: CGFloat = 22

    func update(dt: Double, mood newMood: PetMood, minX: CGFloat, maxX: CGFloat, now: Date) {
        if newMood != mood { mood = newMood }
        // Sleepy, calling or celebrating: stay put.
        guard mood == .idle || mood == .sad else {
            if walking { walking = false }
            return
        }
        if now >= phaseUntil {
            let walk = !walking && Double.random(in: 0...1) < 0.7
            walking = walk
            if walk, Double.random(in: 0...1) < 0.5 { facingLeft.toggle() }
            phaseUntil = now.addingTimeInterval(walk ? Double.random(in: 4...9) : Double.random(in: 3...7))
        }
        guard walking else { return }
        x += (facingLeft ? -1 : 1) * speed * (mood == .sad ? 0.6 : 1) * dt
        if x <= minX { x = minX; facingLeft = false }
        if x >= maxX { x = maxX; facingLeft = true }
    }
}

struct DesktopPetView: View {
    @ObservedObject var model: DesktopPetModel
    @EnvironmentObject var store: AppStore
    var onTap: () -> Void

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            PetCanvas(look: store.petLook, mood: model.mood,
                      t: timeline.date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86_400),
                      effects: model.mood == .alert || model.mood == .sleepy || model.mood == .happy,
                      motion: model.walking ? .walk : nil)
                .scaleEffect(x: model.facingLeft ? -1 : 1, y: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .help(store.settings.petName)
    }
}
