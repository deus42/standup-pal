import AppKit
import SwiftUI

/// After bedtime: the pet in its nightcap sends you away from the Mac. Silent, never
/// takes focus, and fades away by itself after a couple of minutes.
@MainActor
final class BedtimeController {
    static let lingerSeconds: Double = 120

    private var panel: NSPanel?
    private var finish: DispatchWorkItem?

    var contentView: NSView? { panel?.contentView }

    func show(again: Bool) {
        close()
        let view = BedtimeView(again: again,
                               onSleep: { [weak self] in
                                   self?.close()
                                   Self.sleepDisplay()
                               },
                               onLater: { [weak self] in self?.close() })
            .environmentObject(AppStore.shared)
        panel = CornerCard.present(view)

        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.close() }
        }
        finish = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.lingerSeconds, execute: work)
    }

    func close() {
        finish?.cancel()
        finish = nil
        guard let panel else { return }
        self.panel = nil
        CornerCard.dismiss(panel)
    }

    /// Turns the screen off, the same as a hot corner would. The Mac keeps running.
    private static func sleepDisplay() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        try? process.run()
    }
}

struct BedtimeView: View {
    @EnvironmentObject var store: AppStore
    /// Sent once tonight already.
    let again: Bool
    var onSleep: () -> Void
    var onLater: () -> Void

    var body: some View {
        let s = store.settings
        let bed = Clock.time(minute: s.bedtimeMinute)
        HStack(alignment: .top, spacing: 12) {
            Group {
                if s.petEnabled {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                        PetCanvas(look: store.petLook.dressed(for: s.dayOutfits ? .night : nil), mood: .sleepy,
                                  t: timeline.date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86_400))
                    }
                } else {
                    Text("🌙").font(.system(size: 34))
                }
            }
            .frame(width: 70, height: 70)
            VStack(alignment: .leading, spacing: 4) {
                Text(again ? tr("Still at the computer? 👀", "Ти ще за компом? 👀", "Ты ещё за компом? 👀")
                           : tr("Bedtime 🌙", "Час спати 🌙", "Пора спать 🌙"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text(again
                     ? tr("I can't fall asleep while you're working. Off to bed! I'll check again in half an hour.",
                          "Мені не спиться, поки ти працюєш. Гайда спати! Перевірю ще раз за пів години.",
                          "Мне не спится, пока ты работаешь. Давай спать! Проверю ещё раз через полчаса.")
                     : tr("It's \(bed), so I'm off to bed. Close the laptop and rest too: we stretch again tomorrow.",
                          "Уже \(bed), тож я йду спати. Закривай ноутбук і теж відпочивай: завтра знову розминаємось.",
                          "Уже \(bed), так что я иду спать. Закрывай ноутбук и тоже отдыхай: завтра снова разминаемся."))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button(tr("Off to bed 💤", "Іду спати 💤", "Иду спать 💤"), action: onSleep)
                        .buttonStyle(PillButtonStyle(prominent: true, tint: store.accent, compact: true))
                        .fixedSize()
                        .help(tr("Turns the screen off", "Вимкне екран", "Выключит экран"))
                    Button(tr("A bit longer", "Ще трошки", "Ещё чуть-чуть"), action: onLater)
                        .buttonStyle(PillButtonStyle(compact: true))
                        .fixedSize()
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: 370)
        .environment(\.locale, L10n.locale)
        .id(store.settings.language)
    }
}
