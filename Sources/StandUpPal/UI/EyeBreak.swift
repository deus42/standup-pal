import AppKit
import SwiftUI

/// The 20-20-20 eye break: a small card that counts down 20 seconds while the pet looks
/// into the distance, then closes itself. Silent, and it never takes keyboard focus.
@MainActor
final class EyeBreakController {
    static let seconds: Double = 20

    private var panel: NSPanel?
    private var finish: DispatchWorkItem?

    var contentView: NSView? { panel?.contentView }

    func show(credit: Bool = true) {
        close()
        let view = EyeBreakView(started: Date(), onClose: { [weak self] in self?.close() })
            .environmentObject(AppStore.shared)
        panel = CornerCard.present(view)

        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                if credit { Scheduler.shared.completeEyeBreak() }
                self?.close()
            }
        }
        finish = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.seconds, execute: work)
    }

    func close() {
        finish?.cancel()
        finish = nil
        guard let panel else { return }
        self.panel = nil
        CornerCard.dismiss(panel)
    }
}

struct EyeBreakView: View {
    @EnvironmentObject var store: AppStore
    let started: Date
    var onClose: () -> Void

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(started)
            let left = max(0, EyeBreakController.seconds - elapsed)
            HStack(spacing: 12) {
                ZStack {
                    ProgressRing(progress: min(1, elapsed / EyeBreakController.seconds), lineWidth: 4, tint: store.accent)
                    if store.settings.petEnabled {
                        PetCanvas(look: Scheduler.shared.dressedLook(at: timeline.date), mood: .exercise,
                                  t: timeline.date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86_400),
                                  effects: false, motion: .eyes)
                            .padding(5)
                    } else {
                        Text("👀").font(.system(size: 26))
                    }
                }
                .frame(width: 66, height: 66)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("Eye break", "Перерва для очей", "Перерыв для глаз"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text(tr("Look at something 6 metres away until the circle fills.",
                            "Подивись на щось за 6 метрів, поки коло заповниться.",
                            "Посмотри на что-нибудь в 6 метрах, пока круг не заполнится."))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(Words.seconds(Int(left.rounded(.up))))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(store.accent)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(width: 350)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(9)
            .help(tr("Not now", "Не зараз", "Не сейчас"))
        }
        .environment(\.locale, L10n.locale)
        .id(store.settings.language)
    }
}
