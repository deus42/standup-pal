import AppKit
import SwiftUI

/// The pet on top of the Dock. Opt-in, and it keeps to itself unless you play: it walks
/// (in pyjamas after work), sleeps in its bed after bedtime and hops when it's time to
/// stand up. Pick it up and drag it around, toss it (it bounces, and gets dizzy if you
/// overdo it), double-click for a flip, or stroke it with the cursor. Its eyes follow
/// the cursor.
@MainActor
final class DesktopPetController {
    private let model = DesktopPetModel()
    private var panel: NSPanel?
    private var timer: Timer?
    private var fast = false
    private var last = Date()
    private let size = CGSize(width: 104, height: 104)

    private static let gravity: CGFloat = 2600
    private static let maxThrow: CGFloat = 2600
    private static let flipSpeed: CGFloat = 720

    /// Where on the pet you grabbed it, from the panel's corner.
    private var grab = CGPoint.zero
    private var samples: [(time: Date, point: CGPoint)] = []
    private var lastMouse: CGPoint?
    private var stroke: Double = 0
    private var strokeCooldown = Date.distantPast

    init() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.timer?.invalidate()
                self?.timer = nil
            }
        }
        center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if self?.panel != nil { self?.startTimer(fast: false) } }
        }
    }

    func setEnabled(_ on: Bool) {
        if on { show() } else { hide() }
    }

    private func show() {
        guard panel == nil, let screen = NSScreen.main else { return }
        let hosting = NSHostingView(rootView: DesktopPetView(model: model).environmentObject(AppStore.shared))
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.autoresizingMask = [.width, .height]
        let mouse = PetMouseView(frame: NSRect(origin: .zero, size: size))
        mouse.addSubview(hosting)
        mouse.onPress = { [weak self] in self?.press() }
        mouse.onDrag = { [weak self] in self?.dragged() }
        mouse.onRelease = { [weak self] clicks, moved in self?.release(clicks: clicks, moved: moved) }

        let panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: size),
                                  styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = mouse
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        model.x = screen.visibleFrame.midX - size.width / 2
        model.height = 0
        panel.setFrameOrigin(NSPoint(x: model.x, y: floorY(screen.visibleFrame)))
        panel.orderFrontRegardless()
        self.panel = panel
        startTimer(fast: false)
    }

    private func hide() {
        timer?.invalidate()
        timer = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func startTimer(fast: Bool) {
        timer?.invalidate()
        self.fast = fast
        last = Date()
        let t = Timer(timeInterval: fast ? 1.0 / 60.0 : 1.0 / 20.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.step() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: Playing

    private func press() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        grab = CGPoint(x: mouse.x - panel.frame.minX, y: mouse.y - panel.frame.minY)
        samples = [(Date(), mouse)]
        model.held = true
        model.flying = false
        model.flipping = false
        if !fast { startTimer(fast: true) }
    }

    private func dragged() {
        guard let panel, model.held else { return }
        let mouse = NSEvent.mouseLocation
        let now = Date()
        samples.append((now, mouse))
        samples.removeAll { now.timeIntervalSince($0.time) > 0.1 }
        let frame = screen(containing: mouse).visibleFrame
        model.x = min(max(mouse.x - grab.x, frame.minX), frame.maxX - size.width)
        model.height = min(max(mouse.y - grab.y - floorY(frame), 0), frame.height - size.height)
        panel.setFrameOrigin(NSPoint(x: model.x, y: floorY(frame) + model.height))
    }

    private func release(clicks: Int, moved: Bool) {
        model.held = false
        if moved, let first = samples.first, let last = samples.last, last.time > first.time {
            // Toss it with the speed the cursor had.
            let dt = CGFloat(last.time.timeIntervalSince(first.time))
            model.vx = clamp((last.point.x - first.point.x) / dt, Self.maxThrow)
            model.vy = clamp((last.point.y - first.point.y) / dt, Self.maxThrow)
            model.flying = true
            model.peakImpact = 0
            model.spinTravel = 0
            return
        }
        if model.height > 0 {
            // Let go in mid-air: down it goes.
            model.vx = 0
            model.vy = 0
            model.flying = true
            return
        }
        if clicks >= 2 {
            model.vx = 0
            model.vy = Self.flipSpeed
            model.flying = true
            model.flipping = true
            model.spin = 0
            SoundPlayer.shared.play(.boop)
        } else {
            AppStore.shared.react(.happy, for: 3)
            model.play(.happy, for: 2.5)
            SoundPlayer.shared.play(.boop)
        }
    }

    private func land() {
        model.flying = false
        model.vx = 0
        model.vy = 0
        if model.flipping {
            model.flipping = false
            model.spin = 0
            model.play(.celebrate, for: 1.4)
        } else if model.peakImpact > 1300 || model.spinTravel > 540 {
            model.play(.dizzy, for: 2.8)
        } else {
            model.play(.happy, for: 1.2)
        }
    }

    // MARK: Every frame

    private func step() {
        guard let panel else { return }
        let now = Date()
        let dt = CGFloat(min(0.05, now.timeIntervalSince(last)))
        last = now
        let mouse = NSEvent.mouseLocation
        let frame = screen(containing: CGPoint(x: panel.frame.midX, y: panel.frame.midY)).visibleFrame
        let maxX = frame.maxX - size.width
        let ceiling = frame.height - size.height

        if model.flying {
            model.vy -= Self.gravity * dt
            model.x += model.vx * dt
            model.height += model.vy * dt
            if model.flipping {
                let airtime = 2 * Self.flipSpeed / Self.gravity
                model.spin = min(360, model.spin + 360 * Double(dt / airtime))
            } else {
                let turn = Double(model.vx * dt) * 0.35
                model.spin += turn
                model.spinTravel += abs(turn)
            }
            if model.x < frame.minX { model.x = frame.minX; model.vx = abs(model.vx) * 0.55 }
            if model.x > maxX { model.x = maxX; model.vx = -abs(model.vx) * 0.55 }
            if model.height > ceiling { model.height = ceiling; model.vy = -abs(model.vy) * 0.3 }
            if model.height <= 0, model.vy < 0 {
                model.height = 0
                let impact = -model.vy
                model.peakImpact = max(model.peakImpact, impact)
                if impact > 240, !model.flipping {
                    model.vy = impact * 0.42
                    model.vx *= 0.75
                } else {
                    land()
                }
            }
        } else if !model.held, model.spin != 0 {
            // Settle back upright after a tumble.
            let upright = (model.spin / 360).rounded() * 360
            model.spin += (upright - model.spin) * 0.3
            if abs(upright - model.spin) < 1 { model.spin = 0 }
        }

        if model.held {
            let speed = samples.count > 1 ? (samples[samples.count - 1].point.x - samples[0].point.x) / 0.1 : 0
            model.swing += (Double(clamp(-speed * 0.012, 28)) - model.swing) * 0.25
        } else if model.swing != 0 {
            model.swing *= 0.7
            if abs(model.swing) < 0.5 { model.swing = 0 }
        }

        let base = Scheduler.shared.petMood(at: now)
        let night = Scheduler.shared.dayPhase(at: now) == .night
        let look = Scheduler.shared.dressedLook(at: now)
        if model.look != look { model.look = look }

        let center = CGPoint(x: model.x + size.width / 2, y: floorY(frame) + model.height + size.height / 2)
        updateStroking(mouse: mouse, center: center, dt: Double(dt), now: now)
        let gaze = self.gaze(mouse: mouse, center: center, sleeping: base == .sleepy)
        if model.gaze != gaze { model.gaze = gaze }

        var mood = base
        if let play = model.playMood, now < model.playUntil { mood = play } else { model.playMood = nil }
        if model.held { mood = night ? .sleepy : .happy }
        if model.flying { mood = model.flipping ? .celebrate : .alert }
        let inBed = night && base == .sleepy && model.playMood == nil && !model.held && !model.flying && model.height == 0
        if model.inBed != inBed { model.inBed = inBed }
        model.stroll(dt: Double(dt), mood: mood, active: !model.held && !model.flying && model.playMood == nil,
                     minX: frame.minX, maxX: maxX, now: now)
        if model.mood != mood { model.mood = mood }
        let motion: ExerciseMotion? = model.held ? .dangle : (model.walking ? .walk : nil)
        if model.motion != motion { model.motion = motion }

        panel.setFrameOrigin(NSPoint(x: model.x, y: floorY(frame) + model.height))
        let busy = model.held || model.flying || model.spin != 0 || model.swing != 0
        if busy != fast { startTimer(fast: busy) }
    }

    /// Moving the cursor back and forth over the pet counts as stroking it.
    private func updateStroking(mouse: CGPoint, center: CGPoint, dt: Double, now: Date) {
        defer { lastMouse = mouse }
        stroke *= exp(-dt * 1.2)
        guard !model.held, !model.flying, let lastMouse,
              abs(mouse.x - center.x) < 36, abs(mouse.y - center.y) < 36 else { return }
        stroke += Double(hypot(mouse.x - lastMouse.x, mouse.y - lastMouse.y))
        if stroke > 380, now > strokeCooldown {
            stroke = 0
            strokeCooldown = now.addingTimeInterval(1.6)
            model.play(.happy, for: 1.6)
        }
    }

    private func gaze(mouse: CGPoint, center: CGPoint, sleeping: Bool) -> CGPoint? {
        let dx = mouse.x - center.x, dy = mouse.y - center.y
        guard !sleeping, !model.flying, hypot(dx, dy) < 500 else { return nil }
        // Coarse steps, so the view only redraws when the look really changes.
        let x = (Double(clamp(dx / 90, 1)) * 2 * (model.facingLeft ? -1 : 1) * 4).rounded() / 4
        let y = (Double(clamp(-dy / 90, 1)) * 1.3 * 4).rounded() / 4
        return CGPoint(x: x, y: y)
    }

    private func floorY(_ frame: NSRect) -> CGFloat { frame.minY - 8 }

    private func screen(containing point: CGPoint) -> NSScreen {
        NSScreen.screens.first { $0.frame.contains(point) } ?? panel?.screen ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private func clamp(_ value: CGFloat, _ limit: CGFloat) -> CGFloat { min(max(value, -limit), limit) }
}

/// Takes the mouse for the pet: press, drag and release, in screen coordinates.
final class PetMouseView: NSView {
    var onPress: (() -> Void)?
    var onDrag: (() -> Void)?
    var onRelease: ((_ clicks: Int, _ moved: Bool) -> Void)?
    private var start = NSPoint.zero
    private var moved = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        start = NSEvent.mouseLocation
        moved = false
        onPress?()
    }

    override func mouseDragged(with event: NSEvent) {
        let p = NSEvent.mouseLocation
        if !moved, hypot(p.x - start.x, p.y - start.y) < 3 { return }
        moved = true
        onDrag?()
    }

    override func mouseUp(with event: NSEvent) {
        onRelease?(event.clickCount, moved)
    }
}

@MainActor
final class DesktopPetModel: ObservableObject {
    @Published var walking = false
    @Published var facingLeft = false
    @Published var mood: PetMood = .idle
    @Published var look: PetLook?
    @Published var motion: ExerciseMotion?
    @Published var gaze: CGPoint?
    /// Degrees: tumbling through the air, or a backflip.
    @Published var spin: Double = 0
    /// Degrees: swinging while you carry it.
    @Published var swing: Double = 0
    @Published var held = false
    @Published var inBed = false

    var x: CGFloat = 0
    /// Above the floor (the top of the Dock).
    var height: CGFloat = 0
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    var flying = false
    var flipping = false
    var peakImpact: CGFloat = 0
    var spinTravel: Double = 0
    /// A reaction to being played with, for a moment.
    var playMood: PetMood?
    var playUntil = Date.distantPast

    private var phaseUntil = Date()
    private let speed: CGFloat = 22

    func play(_ mood: PetMood, for seconds: TimeInterval) {
        playMood = mood
        playUntil = Date().addingTimeInterval(seconds)
    }

    /// Wanders left and right when it's calm; stays put when sleepy, calling or busy.
    func stroll(dt: Double, mood: PetMood, active: Bool, minX: CGFloat, maxX: CGFloat, now: Date) {
        guard active, mood == .idle || mood == .sad else {
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

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let t = timeline.date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86_400)
            let look = model.look ?? store.petLook
            if model.inBed {
                Canvas { context, size in
                    BedPainter(look: look, t: t).draw(&context, in: CGRect(x: 2, y: 0, width: size.width - 4, height: size.height - 7))
                }
            } else {
                PetCanvas(look: look, mood: model.mood, t: t,
                          effects: [.alert, .sleepy, .happy, .celebrate, .dizzy].contains(model.mood),
                          motion: model.motion, gaze: model.gaze)
                    .scaleEffect(x: model.facingLeft ? -1 : 1, y: 1)
                    .rotationEffect(.degrees(model.spin + model.swing), anchor: model.held ? .top : .center)
            }
        }
    }
}
