import SwiftUI

struct PetSettings: View {
    @EnvironmentObject var store: AppStore
    @ViewState private var previewMood: PetMood = .idle
    @ViewState private var confirmReset = false

    var body: some View {
        VStack(spacing: 16) {
            PetHeaderCard(previewMood: $previewMood)

            SettingsGroup(title: tr("Species", "Вид", "Вид")) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(PetSpecies.allCases) { species in
                        speciesTile(species)
                    }
                }
                .padding(8)
            }

            SettingsGroup(title: tr("Colours", "Кольори", "Цвета")) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(36), spacing: 9), count: 14), spacing: 9) {
                    ForEach(PetPalette.all) { palette in
                        swatch(palette)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 10)
                Divider().padding(.leading, 12)
                HStack(spacing: 10) {
                    Text(currentPaletteName).font(.system(size: 13, weight: .medium))
                    Spacer()
                    ColorPicker(tr("Custom colour", "Свій колір", "Свой цвет"), selection: colorBinding, supportsOpacity: false)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            HStack {
                Text(tr("Tap the pet to see its moods.", "Тицьни на улюбленця, щоб побачити настрої.", "Ткни в питомца, чтобы увидеть настроения."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(tr("Reset progress…", "Скинути прогрес…", "Сбросить прогресс…"), role: .destructive) { confirmReset = true }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                    .font(.system(size: 12))
            }
        }
        .confirmationDialog(tr("Reset \(store.settings.petName)'s progress?", "Скинути прогрес \(store.settings.petName)?",
                               "Сбросить прогресс \(store.settings.petName)?"), isPresented: $confirmReset) {
            Button(tr("Reset XP, levels, gear and stats", "Скинути XP, рівні, спорядження й статистику",
                      "Сбросить XP, уровни, снаряжение и статистику"), role: .destructive) { store.resetProgress() }
        } message: {
            Text(tr("Your settings and reminders stay. This can't be undone.", "Налаштування й нагадування залишаться. Це не можна скасувати.",
                    "Настройки и напоминания останутся. Это нельзя отменить."))
        }
    }

    private var currentPaletteName: String {
        PetPalette.matching(body: store.settings.petColorHex, belly: store.settings.petBellyHex)?.name
            ?? tr("Custom colour", "Свій колір", "Свой цвет")
    }

    private func speciesTile(_ species: PetSpecies) -> some View {
        let selected = store.settings.petSpecies == species
        var look = store.petLook
        look.species = species
        return Button {
            store.settings.petSpecies = species
            SoundPlayer.shared.play(.boop)
        } label: {
            VStack(spacing: 2) {
                PetCanvas(look: look, mood: .idle, t: PetPainter.showcaseTime(for: species), effects: false)
                    .frame(width: 54, height: 54)
                Text(species.label)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(species.role)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(selected ? store.petColor.opacity(0.3) : Color.primary.opacity(0.035)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(selected ? store.accent : Color.clear, lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(species.label) · \(species.role)")
    }

    private func swatch(_ palette: PetPalette) -> some View {
        let selected = PetPalette.matching(body: store.settings.petColorHex, belly: store.settings.petBellyHex) == palette
        return Button {
            store.settings.petColorHex = palette.body
            store.settings.petBellyHex = palette.belly
        } label: {
            Circle()
                .fill(LinearGradient(stops: [.init(color: Color(hex: palette.body), location: 0.56),
                                             .init(color: Color(hex: palette.belly), location: 0.56)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.14), lineWidth: 1))
                .frame(width: 29, height: 29)
                .padding(3.5)
                .overlay(Circle().strokeBorder(selected ? store.accent : Color.clear, lineWidth: 2.2))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(palette.name)
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { store.petColor },
            set: {
                store.settings.petColorHex = RGB(color: $0).hex
                store.settings.petBellyHex = ""
            }
        )
    }
}

/// The pet portrait at the top of the Pet tab: name, level, XP and happiness.
struct PetHeaderCard: View {
    @EnvironmentObject var store: AppStore
    @Binding var previewMood: PetMood

    var body: some View {
        let info = PetState.levelInfo(xp: store.pet.xp)
        let species = store.settings.petSpecies
        HStack(spacing: 20) {
            PetView(look: store.petLook, mood: previewMood)
                .frame(width: 128, height: 128)
                .contentShape(Circle())
                .onTapGesture { cycleMood() }
                .help(previewMood.label)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    TextField("", text: $store.settings.petName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .fixedSize()
                        .help(tr("Rename", "Перейменувати", "Переименовать"))
                    LevelBadge(level: info.level, tint: store.accent)
                }
                Text("\(species.label) · \(species.role) · \(previewMood.label)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                meter(title: tr("\(info.into) / \(info.needed) XP to level \(info.level + 1)",
                                "\(info.into) / \(info.needed) XP до рівня \(info.level + 1)",
                                "\(info.into) / \(info.needed) XP до уровня \(info.level + 1)"),
                      value: Double(info.into) / Double(max(1, info.needed)), tint: store.accent)
                meter(title: tr("Happiness \(Int(store.pet.happiness))%", "Щастя \(Int(store.pet.happiness))%",
                                "Счастье \(Int(store.pet.happiness))%"),
                      value: store.pet.happiness / 100, tint: Color(hex: "#F28DB2"))
                Toggle(tr("Show the pet in the menu bar and reminders", "Показувати улюбленця в рядку меню й нагадуваннях",
                          "Показывать питомца в строке меню и напоминаниях"), isOn: $store.settings.petEnabled)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [store.petColor.opacity(0.32), store.petColor.opacity(0.08)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
    }

    private func meter(title: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.1))
                    Capsule().fill(tint.gradient).frame(width: max(6, geo.size.width * min(1, max(0, value))))
                }
            }
            .frame(width: 300, height: 6)
        }
    }

    private func cycleMood() {
        let all = PetMood.allCases
        let index = all.firstIndex(of: previewMood) ?? 0
        previewMood = all[(index + 1) % all.count]
        SoundPlayer.shared.play(.boop)
    }
}
