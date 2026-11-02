import AppKit
import SwiftUI

/// The Friday card: a week of moving, ready to save or paste into a post.
struct WeeklyCardView: View {
    let summary: WeeklySummary
    let look: PetLook
    let petName: String
    let level: Int
    let streak: Int

    private let ink = Color(.sRGB, red: 0.2, green: 0.16, blue: 0.29)

    var body: some View {
        ZStack {
            LinearGradient(colors: [look.color.lighter(0.62).color, look.belly.color, look.color.lighter(0.4).color],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            HStack(alignment: .center, spacing: 36) {
                VStack(spacing: 6) {
                    PetCanvas(look: look, mood: .celebrate, t: 0.3)
                        .frame(width: 360, height: 360)
                    Text(petName).font(.system(size: 34, weight: .heavy, design: .rounded)).foregroundColor(ink)
                    Text(tr("Level \(level)", "Рівень \(level)", "Уровень \(level)"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 5)
                        .background(Capsule().fill(look.color.darker(0.42).color))
                }
                .frame(width: 400)

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("My week of moving", "Мій тиждень руху", "Моя неделя движения"))
                            .font(.system(size: 46, weight: .heavy, design: .rounded))
                            .foregroundColor(ink)
                        Text(dateRange)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(ink.opacity(0.6))
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(196), spacing: 14), count: 3), alignment: .leading, spacing: 14) {
                        tile("🧍", "\(summary.standups)", tr("stand-ups", "перерв", "перерывов"))
                        tile("🤸", "\(summary.warmUps)", tr("warm-ups", "розминок", "разминок"))
                        tile("⏱️", "\(summary.minutes)", tr("minutes moving", "хвилин руху", "минут движения"))
                        tile("💧", "\(summary.water)", tr("glasses of water", "склянок води", "стаканов воды"))
                        tile("👀", "\(summary.eyeBreaks)", tr("eye breaks", "перерв для очей", "перерывов для глаз"))
                        tile("🔥", "\(streak)", tr("day streak", "днів поспіль", "дней подряд"))
                    }
                    chart
                }
            }
            .padding(.horizontal, 56)
            .padding(.bottom, 20)
        }
        .overlay(alignment: .bottomTrailing) {
            Text("StandUp Pal · github.com/deus42/standup-pal")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(ink.opacity(0.55))
                .padding(24)
        }
        .frame(width: 1200, height: 675)
        .environment(\.colorScheme, .light)
    }

    private func tile(_ emoji: String, _ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(emoji) \(value)").font(.system(size: 36, weight: .heavy, design: .rounded)).foregroundColor(ink)
            Text(caption).font(.system(size: 17, weight: .medium, design: .rounded)).foregroundColor(ink.opacity(0.65))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(width: 196, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.6)))
    }

    private var chart: some View {
        let top = max(1, summary.days.map(\.standups).max() ?? 1)
        return HStack(alignment: .bottom, spacing: 16) {
            ForEach(Array(summary.days.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(day.standups > 0 ? look.color.darker(0.3).color : ink.opacity(0.12))
                        .frame(width: 44, height: max(6, 78 * CGFloat(day.standups) / CGFloat(top)))
                    Text(Clock.shortWeekdaySymbol(Clock.weekday(day.date)))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(ink.opacity(0.6))
                }
            }
        }
        .frame(height: 104, alignment: .bottom)
    }

    private var dateRange: String {
        let f = DateIntervalFormatter()
        f.locale = L10n.locale
        f.dateTemplate = "dMMM"
        return f.string(from: summary.start, to: Clock.addDays(6, to: summary.start))
    }

    /// The card as a 2400×1350 PNG.
    @MainActor
    func renderPNG() -> Data? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 2
        guard let image = renderer.cgImage else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }
}

/// A small window showing the card, with Copy and Save.
@MainActor
final class WeeklyCardController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    var onClose: (() -> Void)?

    var contentView: NSView? { window?.contentView }

    func open(weekStart: Date) {
        let store = AppStore.shared
        let card = WeeklyCardView(summary: WeeklySummary.make(weekStart: weekStart, stats: store.stats, dailyGoal: store.settings.dailyGoal),
                                  look: store.petLook, petName: store.settings.petName,
                                  level: store.pet.level, streak: store.currentStreak())
        let view = WeeklyCardWindowView(card: card, tint: store.accent) { [weak self] in self?.window?.close() }
        if let window {
            (window.contentViewController as? NSHostingController<WeeklyCardWindowView>)?.rootView = view
        } else {
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            self.window = window
        }
        window?.title = tr("Your week", "Твій тиждень", "Твоя неделя")
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() { window?.close() }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}

struct WeeklyCardWindowView: View {
    let card: WeeklyCardView
    let tint: Color
    var onClose: () -> Void
    @ViewState private var copied = false

    var body: some View {
        VStack(spacing: 16) {
            card
                .scaleEffect(0.5, anchor: .topLeading)
                .frame(width: 600, height: 337.5, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
            HStack(spacing: 10) {
                Button(copied ? tr("Copied ✓", "Скопійовано ✓", "Скопировано ✓") : tr("Copy image", "Копіювати картинку", "Копировать картинку")) {
                    copy()
                }
                .buttonStyle(PillButtonStyle(prominent: true, tint: tint))
                .fixedSize()
                Button(tr("Save PNG…", "Зберегти PNG…", "Сохранить PNG…")) { save() }
                    .buttonStyle(PillButtonStyle())
                    .fixedSize()
                Spacer()
                Button(tr("Close", "Закрити", "Закрыть")) { onClose() }
                    .buttonStyle(PillButtonStyle(compact: true))
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 640)
        .environment(\.locale, L10n.locale)
    }

    private func copy() {
        guard let data = card.renderPNG(), let image = NSImage(data: data) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        copied = true
    }

    private func save() {
        guard let data = card.renderPNG() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "StandUp Pal \(Clock.dayKey(card.summary.start)).png"
        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }
}
