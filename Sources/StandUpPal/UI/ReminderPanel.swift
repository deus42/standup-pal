import AppKit
import SwiftUI

enum ReminderAction {
    case warmUp, stoodUp, done, snooze(Int), skip
}

final class Nudger: ObservableObject {
    @Published var count = 0
}

/// A floating, non-activating card in the top-right corner. It never steals focus
/// from what you're typing.
@MainActor
final class ReminderPanelController {
    private var panel: NSPanel?
    private let nudger = Nudger()

    var isVisible: Bool { panel != nil }
    var contentView: NSView? { panel?.contentView }

    func show(occurrence: Occurrence, onAction: @escaping (ReminderAction) -> Void) {
        close(animated: false)
        let store = AppStore.shared
        let reminder = occurrence.customID.flatMap { id in store.reminders.first { $0.id == id } }
        let card = ReminderCardView(occurrence: occurrence, reminder: reminder, nudger: nudger, onAction: onAction)
            .environmentObject(store)

        let hosting = NSHostingView(rootView: card)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        let size = hosting.fittingSize

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.maskImage = Self.roundedMask(radius: 20)
        effect.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: effect.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])

        let panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: size),
                                  styleMask: [.borderless, .nonactivatingPanel],
                                  backing: .buffered, defer: false)
        panel.contentView = effect
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none

        let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? .zero
        let target = NSPoint(x: visible.maxX - size.width - 14, y: visible.maxY - size.height - 10)
        panel.setFrameOrigin(NSPoint(x: target.x + 40, y: target.y))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.invalidateShadow()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrameOrigin(target)
        }
        self.panel = panel
    }

    func nudge() {
        nudger.count += 1
    }

    func close(animated: Bool = true) {
        guard let panel else { return }
        self.panel = nil
        guard animated else {
            panel.orderOut(nil)
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
            panel.animator().setFrameOrigin(NSPoint(x: panel.frame.origin.x + 30, y: panel.frame.origin.y))
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = 2 * radius + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

struct ReminderCardView: View {
    let occurrence: Occurrence
    let reminder: CustomReminder?
    @ObservedObject var nudger: Nudger
    let onAction: (ReminderAction) -> Void
    @EnvironmentObject var store: AppStore
    @ViewState private var bounce = false
    @ViewState private var lineSeed = Int.random(in: 0..<100)

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            avatar
            VStack(alignment: .leading, spacing: 9) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                buttons
            }
            .padding(.trailing, 10)
        }
        .padding(16)
        .frame(width: 410, alignment: .leading)
        .overlay(alignment: .topTrailing) {
            Button { onAction(.skip) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(10)
            .help("Skip")
        }
        .offset(y: bounce ? -7 : 0)
        .onChange(of: nudger.count) { _, _ in
            withAnimation(.spring(response: 0.18, dampingFraction: 0.4)) { bounce = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { bounce = false }
            }
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if store.settings.petEnabled {
            PetView(look: store.petLook, mood: .alert)
                .frame(width: 88, height: 88)
        } else {
            ZStack {
                Circle().fill(store.petColor.opacity(0.35))
                if let reminder {
                    Text(reminder.emoji).font(.system(size: 34))
                } else {
                    Image(systemName: "figure.stand").font(.system(size: 30, weight: .semibold)).foregroundStyle(store.accent)
                }
            }
            .frame(width: 64, height: 64)
        }
    }

    private var title: String {
        let name = store.settings.petName
        if let reminder {
            return "\(reminder.emoji) \(reminder.title)"
        }
        return store.settings.petEnabled ? "\(name) says: stand up!" : "Time to stand up"
    }

    private var subtitle: String {
        if let reminder {
            if !reminder.note.isEmpty { return reminder.note }
            return occurrence.snoozeCount > 0 ? "Back again, as promised. Ready now?" : "Little extras add up. Got a minute?"
        }
        if occurrence.snoozeCount >= 2 {
            return "Snoozed \(occurrence.snoozeCount)×. Your legs are filing a complaint."
        }
        if occurrence.snoozeCount == 1 {
            return "Five more minutes are up. Let's do this!"
        }
        let lines = [
            "The hour's almost up. Perfect moment for a quick warm-up.",
            "Your chair could use a break from you. Let's stretch!",
            "Up, up, up! A few minutes of moving and you're back.",
            "Stand-up o'clock! Unfold, reach, wiggle.",
        ]
        return lines[lineSeed % lines.count]
    }

    @ViewBuilder
    private var buttons: some View {
        let minutes = store.settings.warmUpLength.minutes
        if occurrence.isStandup {
            VStack(alignment: .leading, spacing: 6) {
                Button { onAction(.warmUp) } label: {
                    Label("Start \(minutes)-min warm-up", systemImage: "figure.cooldown")
                }
                .buttonStyle(PillButtonStyle(prominent: true, tint: store.accent))
                HStack(spacing: 6) {
                    Button { onAction(.stoodUp) } label: { Label("Stood up", systemImage: "checkmark") }
                    if occurrence.snoozeCount < 3 {
                        let snooze = store.settings.snoozeMinutes
                        Button { onAction(.snooze(snooze)) } label: { Label("\(snooze) min", systemImage: "moon.zzz") }
                    }
                    Button("Skip") { onAction(.skip) }
                }
                .buttonStyle(PillButtonStyle(compact: true))
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Button { onAction(.done) } label: { Label("Done!", systemImage: "checkmark") }
                    .buttonStyle(PillButtonStyle(prominent: true, tint: store.accent))
                HStack(spacing: 6) {
                    Button { onAction(.snooze(60)) } label: { Label("+1 hour", systemImage: "clock.arrow.circlepath") }
                    Button("+2 hours") { onAction(.snooze(120)) }
                    Button("Skip") { onAction(.skip) }
                }
                .buttonStyle(PillButtonStyle(compact: true))
            }
        }
    }
}
