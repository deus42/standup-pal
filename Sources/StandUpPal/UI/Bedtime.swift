import AppKit
import SwiftUI

/// After bedtime: time to log off. The pet shuts its laptop, walks to bed and falls
/// asleep, and asks you to do the same. Never takes focus, and fades away by itself
/// after a couple of minutes.
@MainActor
final class BedtimeController {
    static let lingerSeconds: Double = 120

    private var panel: NSPanel?
    private var finish: DispatchWorkItem?

    var contentView: NSView? { panel?.contentView }

    /// `again` when you've been sent once tonight already; a `preview` counts for nothing.
    func show(again: Bool, preview: Bool = false, startedAt: Date = Date()) {
        close()
        // A repeat starts with the pet already asleep.
        let started = again ? startedAt.addingTimeInterval(-BedtimeScenePainter.duration) : startedAt
        let view = BedtimeView(again: again, started: started,
                               onSleep: { [weak self] in
                                   self?.close()
                                   guard !preview else { return }
                                   Scheduler.shared.wentToBed()
                                   Self.sleepDisplay()
                               },
                               onLater: { [weak self] in self?.close() })
            .environmentObject(AppStore.shared)
        panel = CornerCard.present(view)
        SoundPlayer.shared.play(.goodnight)

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
    let started: Date
    var onSleep: () -> Void
    var onLater: () -> Void

    var body: some View {
        let s = store.settings
        let bed = Clock.time(minute: s.bedtimeMinute)
        VStack(alignment: .leading, spacing: 10) {
            if s.petEnabled {
                BedtimeScene(look: store.petLook, dressed: s.dayOutfits, started: started)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(again ? tr("Still at the computer? 👀", "Ти ще за компом? 👀", "Ты ещё за компом? 👀")
                           : tr("Time to log off 🌙", "Час відключатися 🌙", "Пора отключаться 🌙"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text(again
                     ? tr("I'm already in bed and you're still here. Log off! I'll check again in half an hour.",
                          "Я вже в ліжку, а ти досі тут. Відключайся! Перевірю ще раз за пів години.",
                          "Я уже в кровати, а ты всё ещё тут. Отключайся! Проверю ещё раз через полчаса.")
                     : tr("It's \(bed). I'm shutting my laptop and off to bed. Shut yours too: we stretch again tomorrow.",
                          "Уже \(bed). Я закриваю ноутбук і йду спатки. Закривай і ти: завтра знову розминаємось.",
                          "Уже \(bed). Я закрываю ноутбук и иду спатки. Закрывай и ты: завтра снова разминаемся."))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Button(tr("Off to bed 💤", "Іду спати 💤", "Иду спать 💤"), action: onSleep)
                    .buttonStyle(PillButtonStyle(prominent: true, tint: store.accent, compact: true))
                    .fixedSize()
                    .help(tr("Turns the screen off", "Вимкне екран", "Выключит экран"))
                Button(tr("A bit longer", "Ще трошки", "Ещё чуть-чуть"), action: onLater)
                    .buttonStyle(PillButtonStyle(compact: true))
                    .fixedSize()
            }
        }
        .padding(14)
        .frame(width: 370)
        .environment(\.locale, L10n.locale)
        .id(store.settings.language)
    }
}
