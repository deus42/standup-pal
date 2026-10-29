import SwiftUI

struct RemindersSettings: View {
    @EnvironmentObject var store: AppStore
    let actions: AppActions
    @ViewState private var selection: UUID?

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(store.reminders) { reminder in
                        HStack(spacing: 8) {
                            Toggle("", isOn: enabledBinding(reminder.id))
                                .labelsHidden()
                                .toggleStyle(.checkbox)
                            Text(reminder.emoji).font(.system(size: 18))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(reminder.title).lineLimit(1)
                                Text(reminder.scheduleSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 3)
                        .opacity(reminder.isEnabled ? 1 : 0.55)
                        .tag(reminder.id)
                    }
                }
                .listStyle(.sidebar)
                Divider()
                HStack(spacing: 4) {
                    Button { add() } label: { Image(systemName: "plus").frame(width: 22, height: 20) }
                        .help("Add a reminder")
                    Button { remove() } label: { Image(systemName: "minus").frame(width: 22, height: 20) }
                        .disabled(selection == nil)
                        .help("Delete the selected reminder")
                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(6)
            }
            .frame(width: 240)

            Divider()

            if let id = selection, let binding = reminderBinding(id) {
                ReminderEditor(reminder: binding, tint: store.accent) {
                    actions.previewReminder(binding.wrappedValue)
                }
                .id(id)
            } else {
                VStack(spacing: 10) {
                    Text("🗓️").font(.system(size: 44))
                    Text("Extra reminders for push-ups, water, walks… anything.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Add a reminder") { add() }
                        .buttonStyle(PillButtonStyle(prominent: true, tint: store.accent))
                        .fixedSize()
                }
                .padding(30)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if selection == nil { selection = store.reminders.first?.id }
        }
    }

    private func enabledBinding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { store.reminders.first(where: { $0.id == id })?.isEnabled ?? false },
            set: { value in
                if let i = store.reminders.firstIndex(where: { $0.id == id }) { store.reminders[i].isEnabled = value }
            }
        )
    }

    private func reminderBinding(_ id: UUID) -> Binding<CustomReminder>? {
        guard let current = store.reminders.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { store.reminders.first(where: { $0.id == id }) ?? current },
            set: { value in
                if let i = store.reminders.firstIndex(where: { $0.id == id }) { store.reminders[i] = value }
            }
        )
    }

    private func add() {
        var reminder = CustomReminder()
        reminder.title = "Squats"
        reminder.emoji = "🦵"
        reminder.note = "10 slow ones. You've got this."
        reminder.times = [15 * 60 + 30]
        store.reminders.append(reminder)
        selection = reminder.id
    }

    private func remove() {
        guard let id = selection, let index = store.reminders.firstIndex(where: { $0.id == id }) else { return }
        selection = nil
        store.reminders.remove(at: index)
        store.runtime.snoozed.removeAll { $0.customID == id }
        selection = store.reminders.indices.contains(index) ? store.reminders[index].id : store.reminders.last?.id
    }
}

struct ReminderEditor: View {
    @Binding var reminder: CustomReminder
    var tint: Color
    var onPreview: () -> Void

    private let emojiChoices = ["💪", "🦵", "💧", "🚶", "🧘", "👀", "🤸", "🍎", "🫁", "☕️", "🪴", "📵"]

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $reminder.title)
                TextField("Emoji", text: $reminder.emoji)
                HStack(spacing: 0) {
                    ForEach(emojiChoices, id: \.self) { emoji in
                        Button { reminder.emoji = emoji } label: {
                            Text(emoji)
                                .font(.system(size: 16))
                                .frame(maxWidth: .infinity, minHeight: 26)
                                .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(reminder.emoji == emoji ? tint.opacity(0.3) : Color.clear))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                TextField("Note", text: $reminder.note, prompt: Text("Optional, shown on the card"))
                Toggle("Enabled", isOn: $reminder.isEnabled)
            }

            Section("Schedule") {
                Picker("Repeat", selection: $reminder.mode) {
                    Text("At set times").tag(CustomReminder.Mode.times)
                    Text("Every few hours").tag(CustomReminder.Mode.interval)
                }
                .pickerStyle(.segmented)

                if reminder.mode == .times {
                    ForEach(Array(reminder.times.enumerated()), id: \.offset) { index, _ in
                        HStack {
                            DatePicker("Time \(index + 1)", selection: minuteBinding(timeBinding(index)), displayedComponents: .hourAndMinute)
                            Button {
                                if reminder.times.indices.contains(index) { reminder.times.remove(at: index) }
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .disabled(reminder.times.count <= 1)
                        }
                    }
                    Button {
                        let last = reminder.times.max() ?? 10 * 60
                        reminder.times.append(min(last + 60, 23 * 60 + 30))
                    } label: {
                        Label("Add a time", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                } else {
                    Picker("Every", selection: $reminder.intervalMinutes) {
                        ForEach([30, 45, 60, 90, 120, 180, 240], id: \.self) { Text(Clock.durationLabel($0)).tag($0) }
                    }
                    DatePicker("From", selection: minuteBinding($reminder.startMinute), displayedComponents: .hourAndMinute)
                    DatePicker("Until", selection: minuteBinding($reminder.endMinute), displayedComponents: .hourAndMinute)
                }
                LabeledContent("Days") {
                    WeekdayPicker(selection: $reminder.weekdays, tint: tint)
                }
            }

            Section {
                HStack {
                    Button("Show it now") { onPreview() }
                    Spacer()
                    Text(reminder.scheduleSummary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            } footer: {
                Text("When it pops up you can mark it done, skip it, or push it back by 1 or 2 hours.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func timeBinding(_ index: Int) -> Binding<Int> {
        Binding(
            get: { reminder.times.indices.contains(index) ? reminder.times[index] : 12 * 60 },
            set: { value in
                if reminder.times.indices.contains(index) { reminder.times[index] = value }
            }
        )
    }
}
