import SwiftUI

/// Fitness gear: one item per slot, unlocked by levelling up.
struct GearSettings: View {
    @EnvironmentObject var store: AppStore
    @ViewState private var previewMood: PetMood = .exercise

    var body: some View {
        let info = PetState.levelInfo(xp: store.pet.xp)
        HStack(alignment: .top, spacing: 18) {
            VStack(spacing: 10) {
                PetView(look: store.petLook, mood: previewMood)
                    .frame(width: 176, height: 176)
                    .contentShape(Circle())
                    .onTapGesture { cycleMood() }
                    .help(previewMood.label)
                HStack(spacing: 6) {
                    Text(store.settings.petName).font(.system(size: 17, weight: .heavy, design: .rounded))
                    LevelBadge(level: info.level, tint: store.accent)
                }
                ProgressView(value: Double(info.into), total: Double(max(1, info.needed)))
                    .tint(store.accent)
                    .controlSize(.small)
                    .frame(width: 160)
                Text(nextUnlock(level: info.level))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(width: 214)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [store.petColor.opacity(0.32), store.petColor.opacity(0.08)],
                                         startPoint: .top, endPoint: .bottom))
            )

            VStack(spacing: 14) {
                gearGroup(tr("Head", "Голова", "Голова"), HeadGear.allCases, $store.settings.petHead,
                          mood: .idle, t: 1.2, level: info.level) { look(head: $0) }
                gearGroup(tr("Hands", "Руки", "Руки"), HandGear.allCases, $store.settings.petHands,
                          mood: .happy, t: 0.3, level: info.level) { look(hands: $0) }
                gearGroup(tr("Neck", "Шия", "Шея"), NeckGear.allCases, $store.settings.petNeck,
                          mood: .idle, t: 1.2, level: info.level) { look(neck: $0) }
                Text(tr("Earn XP with stand-ups and warm-ups to unlock more gear. Mix and match one item per slot.",
                        "Заробляй XP перервами й розминками, щоб відкрити більше спорядження. Поєднуй по одній речі на кожне місце.",
                        "Зарабатывай XP перерывами и разминками, чтобы открыть больше снаряжения. Сочетай по одной вещи на каждое место."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func gearGroup<G: PetGear>(_ title: String, _ items: [G], _ selection: Binding<G>,
                                       mood: PetMood, t: Double, level: Int,
                                       look: @escaping (G) -> PetLook) -> some View {
        SettingsGroup(title: title) {
            HStack(spacing: 6) {
                ForEach(items) { item in
                    gearTile(item, selected: selection.wrappedValue == item, level: level,
                             look: look(item), mood: mood, t: t) {
                        selection.wrappedValue = item
                        previewMood = mood == .happy ? .exercise : .happy
                        SoundPlayer.shared.play(.boop)
                    }
                }
                ForEach(0..<max(0, 6 - items.count), id: \.self) { _ in
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                }
            }
            .padding(8)
        }
    }

    private func gearTile(_ item: some PetGear, selected: Bool, level: Int, look: PetLook,
                          mood: PetMood, t: Double, action: @escaping () -> Void) -> some View {
        let unlocked = level >= item.unlockLevel
        return Button(action: action) {
            VStack(spacing: 2) {
                ZStack {
                    PetCanvas(look: look, mood: mood, t: t, effects: false)
                        .opacity(unlocked ? 1 : 0.28)
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 50, height: 50)
                Text(unlocked ? item.label : tr("Level \(item.unlockLevel)", "Рівень \(item.unlockLevel)", "Уровень \(item.unlockLevel)"))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(unlocked ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(selected ? store.petColor.opacity(0.3) : Color.primary.opacity(0.035)))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(selected ? store.accent : Color.clear, lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .help(unlocked ? item.label : tr("\(item.label): unlocks at level \(item.unlockLevel)",
                                         "\(item.label): відкриється на рівні \(item.unlockLevel)",
                                         "\(item.label): откроется на уровне \(item.unlockLevel)"))
    }

    private func look(head: HeadGear? = nil, hands: HandGear? = nil, neck: NeckGear? = nil) -> PetLook {
        var look = store.petLook
        if let head { look.head = head }
        if let hands { look.hands = hands }
        if let neck { look.neck = neck }
        return look
    }

    private func nextUnlock(level: Int) -> String {
        guard let next = GearCatalog.next(after: level) else {
            return tr("All gear unlocked. Champion! 🏆", "Усе спорядження відкрито. Чемпіон! 🏆", "Всё снаряжение открыто. Чемпион! 🏆")
        }
        return tr("Next: \(next.label) at level \(next.level)", "Далі: \(next.label) на рівні \(next.level)",
                  "Дальше: \(next.label) на уровне \(next.level)")
    }

    private func cycleMood() {
        let order: [PetMood] = [.exercise, .happy, .celebrate, .idle]
        let index = order.firstIndex(of: previewMood) ?? -1
        previewMood = order[(index + 1) % order.count]
        SoundPlayer.shared.play(.boop)
    }
}
