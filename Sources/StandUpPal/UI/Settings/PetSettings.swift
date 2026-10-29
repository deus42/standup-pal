import SwiftUI

struct PetSettings: View {
    @EnvironmentObject var store: AppStore
    @ViewState private var previewMood: PetMood = .idle
    @ViewState private var confirmReset = false

    var body: some View {
        let info = PetState.levelInfo(xp: store.pet.xp)
        Form {
            Section {
                HStack(spacing: 22) {
                    PetView(look: store.petLook, mood: previewMood)
                        .frame(width: 136, height: 136)
                        .contentShape(Circle())
                        .onTapGesture { cycleMood() }
                        .help("Tap to see moods")
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(store.settings.petName).font(.system(size: 22, weight: .heavy, design: .rounded))
                            LevelBadge(level: info.level, tint: store.accent)
                        }
                        Text("\(info.into) / \(info.needed) XP to level \(info.level + 1)")
                            .font(.caption).foregroundStyle(.secondary)
                        ProgressView(value: Double(info.into), total: Double(info.needed)).tint(store.accent)
                        Text("Happiness \(Int(store.pet.happiness))%").font(.caption).foregroundStyle(.secondary)
                        ProgressView(value: store.pet.happiness, total: 100).tint(Color(hex: "#F28DB2"))
                        Text("Mood preview: \(previewMood.label). Tap me!").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 4)
                Toggle("Show pet", isOn: $store.settings.petEnabled)
                TextField("Name", text: $store.settings.petName)
            }

            Section("Species") {
                HStack(spacing: 10) {
                    ForEach(PetSpecies.allCases) { species in
                        choiceTile(selected: store.settings.petSpecies == species, label: species.label) {
                            PetCanvas(look: look(species: species), mood: .idle, t: 1.2, effects: false)
                        } action: {
                            store.settings.petSpecies = species
                        }
                    }
                }
            }

            Section("Colour") {
                HStack(spacing: 9) {
                    ForEach(PetPalette.swatches) { swatch in
                        let selected = store.settings.petColorHex.uppercased() == swatch.hex
                        Button { store.settings.petColorHex = swatch.hex } label: {
                            Circle()
                                .fill(Color(hex: swatch.hex))
                                .frame(width: 26, height: 26)
                                .overlay(Circle().strokeBorder(Color.primary.opacity(selected ? 0.7 : 0.12), lineWidth: selected ? 2.5 : 1))
                        }
                        .buttonStyle(.plain)
                        .help(swatch.name)
                    }
                    Divider().frame(height: 22)
                    ColorPicker("Custom", selection: colorBinding, supportsOpacity: false)
                        .labelsHidden()
                        .help("Any colour you like")
                }
            }

            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                    ForEach(PetAccessory.allCases) { accessory in
                        let unlocked = info.level >= accessory.unlockLevel
                        choiceTile(selected: store.settings.petAccessory == accessory,
                                   label: unlocked ? accessory.label : "Lv \(accessory.unlockLevel)") {
                            ZStack {
                                PetCanvas(look: look(accessory: accessory), mood: .idle, t: 1.2, effects: false)
                                    .opacity(unlocked ? 1 : 0.25)
                                if !unlocked {
                                    Image(systemName: "lock.fill").foregroundStyle(.secondary)
                                }
                            }
                        } action: {
                            if unlocked { store.settings.petAccessory = accessory }
                        }
                        .disabled(!unlocked)
                    }
                }
            } header: {
                Text("Accessories")
            } footer: {
                Text("Earn XP by standing up and finishing warm-ups to unlock new looks.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Reset pet progress…", role: .destructive) { confirmReset = true }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Reset \(store.settings.petName)'s progress?", isPresented: $confirmReset) {
            Button("Reset XP, levels and stats", role: .destructive) { store.resetProgress() }
        } message: {
            Text("Your settings and reminders stay. This can't be undone.")
        }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { store.petColor },
            set: { store.settings.petColorHex = RGB(color: $0).hex }
        )
    }

    private func look(species: PetSpecies? = nil, accessory: PetAccessory? = nil) -> PetLook {
        var look = store.petLook
        if let species { look.species = species }
        if let accessory { look.accessory = accessory }
        return look
    }

    private func cycleMood() {
        let all = PetMood.allCases
        let index = all.firstIndex(of: previewMood) ?? 0
        previewMood = all[(index + 1) % all.count]
        SoundPlayer.shared.play(.boop)
    }

    private func choiceTile<Content: View>(selected: Bool, label: String,
                                           @ViewBuilder content: () -> Content,
                                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                content().frame(width: 54, height: 54)
                Text(label).font(.system(size: 11, weight: .medium)).lineLimit(1)
            }
            .padding(6)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(selected ? store.petColor.opacity(0.3) : Color.primary.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(selected ? store.accent : Color.clear, lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
