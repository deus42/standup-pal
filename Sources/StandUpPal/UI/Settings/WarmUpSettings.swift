import SwiftUI

struct WarmUpSettings: View {
    @EnvironmentObject var store: AppStore
    @ViewState private var newEmoji = "🏃"
    @ViewState private var newName = ""
    @ViewState private var newInstructions = ""
    @ViewState private var newSeconds = 30

    var body: some View {
        Form {
            Section("Routine") {
                Picker("Length", selection: $store.settings.warmUpLength) {
                    ForEach(WarmUpLength.allCases) { Text($0.label).tag($0) }
                }
                Toggle("3-second get-ready countdown", isOn: $store.settings.getReadyCountdown)
                Toggle("Read exercise names aloud", isOn: $store.settings.speakExercises)
            }

            Section {
                ForEach(ExerciseLibrary.all(store.settings)) { exercise in
                    HStack(spacing: 10) {
                        Toggle("", isOn: enabledBinding(exercise.id))
                            .labelsHidden()
                            .toggleStyle(.checkbox)
                        Text(exercise.emoji).font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                Text(exercise.name)
                                Text("\(exercise.seconds)s").font(.caption).foregroundStyle(.secondary)
                                if exercise.isCustom {
                                    Text("yours")
                                        .font(.system(size: 9.5, weight: .semibold))
                                        .padding(.horizontal, 5).padding(.vertical, 1)
                                        .background(Capsule().fill(store.petColor.opacity(0.35)))
                                }
                            }
                            Text(exercise.instructions)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if exercise.isCustom {
                            Button {
                                store.settings.customExercises.removeAll { $0.id == exercise.id }
                                store.settings.disabledExerciseIDs.remove(exercise.id)
                            } label: {
                                Image(systemName: "trash").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            } header: {
                Text("Exercises in the mix")
            } footer: {
                Text("Every warm-up picks a fresh random mix that fits your chosen length. Your own exercises go in first.")
                    .foregroundStyle(.secondary)
            }

            Section("Add your own exercise") {
                HStack {
                    TextField("Emoji", text: $newEmoji).frame(width: 90)
                    TextField("Name", text: $newName, prompt: Text("e.g. Lunges"))
                }
                TextField("How to do it", text: $newInstructions, prompt: Text("e.g. Step forward, lower slowly, alternate legs."))
                Stepper(value: $newSeconds, in: 10...120, step: 5) {
                    LabeledContent("Duration", value: "\(newSeconds) s")
                }
                HStack {
                    Spacer()
                    Button("Add exercise") { addExercise() }
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func enabledBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { !store.settings.disabledExerciseIDs.contains(id) },
            set: { on in
                if on { store.settings.disabledExerciseIDs.remove(id) } else { store.settings.disabledExerciseIDs.insert(id) }
            }
        )
    }

    private func addExercise() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let exercise = Exercise(
            id: "custom-\(UUID().uuidString)",
            name: name,
            emoji: newEmoji.isEmpty ? "⭐️" : String(newEmoji.prefix(2)),
            instructions: newInstructions.isEmpty ? "Your move. Make it count!" : newInstructions,
            seconds: newSeconds,
            slot: .any,
            isCustom: true)
        store.settings.customExercises.append(exercise)
        newName = ""
        newInstructions = ""
    }
}
