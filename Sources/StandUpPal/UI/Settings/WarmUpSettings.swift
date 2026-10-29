import SwiftUI

struct WarmUpSettings: View {
    @EnvironmentObject var store: AppStore
    @ViewState private var newEmoji = "🏃"
    @ViewState private var newName = ""
    @ViewState private var newInstructions = ""
    @ViewState private var newSeconds = 30

    var body: some View {
        VStack(spacing: 16) {
            SettingsGroup(title: tr("Routine", "Програма", "Программа")) {
                SettingsRow(title: tr("Length", "Тривалість", "Длительность")) {
                    Picker("", selection: $store.settings.warmUpLength) {
                        ForEach(WarmUpLength.allCases) { Text(Words.minutes($0.minutes)).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
                SettingsToggle(title: tr("3-second get-ready countdown", "Відлік 3 секунди перед стартом", "Отсчёт 3 секунды перед стартом"),
                               isOn: $store.settings.getReadyCountdown)
                SettingsToggle(title: tr("Read exercise names aloud", "Озвучувати назви вправ", "Озвучивать названия упражнений"),
                               isOn: $store.settings.speakExercises, divider: false)
            }

            SettingsGroup(title: tr("Exercises in the mix", "Вправи в міксі", "Упражнения в миксе"),
                          footer: tr("Every warm-up picks a fresh random mix that fits your chosen length. Your own exercises go in first. Hover one to read how it's done.",
                                     "Щоразу збирається новий випадковий мікс потрібної тривалості. Твої вправи йдуть першими. Наведи на вправу, щоб прочитати, як її робити.",
                                     "Каждый раз собирается новый случайный микс нужной длительности. Твои упражнения идут первыми. Наведи на упражнение, чтобы прочитать, как его делать.")) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach(ExerciseLibrary.all(store.settings)) { exercise in
                        chip(exercise)
                    }
                }
                .padding(8)
            }

            SettingsGroup(title: tr("Add your own exercise", "Додай свою вправу", "Добавь своё упражнение"),
                          footer: canAdd ? nil : tr("That's the maximum of \(ExerciseLibrary.maxCustom). Delete one to add another.",
                                                    "Це максимум — \(ExerciseLibrary.maxCustom). Видали одну, щоб додати нову.",
                                                    "Это максимум — \(ExerciseLibrary.maxCustom). Удали одно, чтобы добавить новое.")) {
                HStack(spacing: 8) {
                    TextField("", text: $newEmoji)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(width: 44)
                    TextField("", text: $newName, prompt: Text(tr("Name, e.g. Lunges", "Назва, напр. Випади", "Название, напр. Выпады")))
                        .textFieldStyle(.roundedBorder)
                    ValueStepper(value: $newSeconds, range: 10...120, step: 5) { Words.seconds($0) }
                    Button(tr("Add", "Додати", "Добавить")) { addExercise() }
                        .buttonStyle(PillButtonStyle(prominent: true, tint: store.accent, compact: true))
                        .fixedSize()
                        .disabled(!canAdd || newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(10)
                Divider().padding(.leading, 12)
                TextField("", text: $newInstructions,
                          prompt: Text(tr("How to do it (optional)", "Як виконувати (необов'язково)", "Как выполнять (необязательно)")))
                    .textFieldStyle(.roundedBorder)
                    .padding(10)
            }
            .disabled(!canAdd)
        }
    }

    private var canAdd: Bool { store.settings.customExercises.count < ExerciseLibrary.maxCustom }

    private func chip(_ exercise: Exercise) -> some View {
        let on = !store.settings.disabledExerciseIDs.contains(exercise.id)
        return HStack(spacing: 6) {
            Toggle("", isOn: enabledBinding(exercise.id))
                .labelsHidden()
                .toggleStyle(.checkbox)
            Text(exercise.emoji).font(.system(size: 15))
            Text(exercise.name)
                .font(.system(size: 12))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 2)
            Text(Words.seconds(exercise.seconds))
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            if exercise.isCustom {
                Button {
                    store.settings.customExercises.removeAll { $0.id == exercise.id }
                    store.settings.disabledExerciseIDs.remove(exercise.id)
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help(tr("Delete", "Видалити", "Удалить"))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(exercise.isCustom ? store.petColor.opacity(0.22) : Color.primary.opacity(0.04)))
        .opacity(on ? 1 : 0.55)
        .help(exercise.instructions)
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
        guard !name.isEmpty, canAdd else { return }
        let exercise = Exercise(
            id: "custom-\(UUID().uuidString)",
            name: name,
            emoji: newEmoji.isEmpty ? "⭐️" : String(newEmoji.prefix(2)),
            instructions: newInstructions.isEmpty
                ? tr("Your move. Make it count!", "Твій хід. Зроби це красиво!", "Твой ход. Сделай это красиво!")
                : newInstructions,
            seconds: newSeconds,
            slot: .any,
            isCustom: true)
        store.settings.customExercises.append(exercise)
        newName = ""
        newInstructions = ""
    }
}
