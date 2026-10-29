import SwiftUI

struct RemindersSettings: View {
    @EnvironmentObject var store: AppStore
    let actions: AppActions
    @ViewState private var selection: UUID?

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                SettingsGroup(title: tr("Your reminders", "Твої нагадування", "Твои напоминания"),
                              footer: tr("Up to \(CustomReminder.maxCount). The tick turns one on or off.",
                                         "До \(CustomReminder.maxCount) штук. Галочка вмикає чи вимикає.",
                                         "До \(CustomReminder.maxCount) штук. Галочка включает или выключает.")) {
                    if store.reminders.isEmpty {
                        Text(tr("No reminders yet.", "Ще немає нагадувань.", "Пока нет напоминаний."))
                            .foregroundStyle(.secondary)
                            .padding(14)
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(Array(store.reminders.enumerated()), id: \.element.id) { index, reminder in
                        row(reminder, last: index == store.reminders.count - 1)
                    }
                }
                HStack(spacing: 8) {
                    Button { add() } label: { Label(tr("Add", "Додати", "Добавить"), systemImage: "plus") }
                        .disabled(store.reminders.count >= CustomReminder.maxCount)
                    Button { remove() } label: { Label(tr("Delete", "Видалити", "Удалить"), systemImage: "trash") }
                        .disabled(selection == nil)
                }
                .buttonStyle(PillButtonStyle(compact: true))
            }
            .frame(width: 250)

            if let id = selection, let binding = reminderBinding(id) {
                ReminderEditor(reminder: binding, tint: store.accent) {
                    actions.previewReminder(binding.wrappedValue)
                }
                .id(id)
            } else {
                VStack(spacing: 12) {
                    Text("🗓️").font(.system(size: 44))
                    Text(tr("Extra reminders for push-ups, water, walks… anything.",
                            "Додаткові нагадування: віджимання, вода, прогулянки… що завгодно.",
                            "Дополнительные напоминания: отжимания, вода, прогулки… что угодно."))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(tr("Add a reminder", "Додати нагадування", "Добавить напоминание")) { add() }
                        .buttonStyle(PillButtonStyle(prominent: true, tint: store.accent))
                        .fixedSize()
                }
                .padding(30)
                .frame(maxWidth: .infinity, minHeight: 300)
            }
        }
        .onAppear {
            if selection == nil { selection = store.reminders.first?.id }
        }
    }

    private func row(_ reminder: CustomReminder, last: Bool) -> some View {
        let selected = selection == reminder.id
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Toggle("", isOn: enabledBinding(reminder.id))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                Text(reminder.emoji).font(.system(size: 18))
                VStack(alignment: .leading, spacing: 1) {
                    Text(reminder.title).font(.system(size: 13, weight: selected ? .semibold : .regular)).lineLimit(1)
                    Text(reminder.scheduleSummary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? store.petColor.opacity(0.28) : Color.clear)
                .padding(3))
            .opacity(reminder.isEnabled ? 1 : 0.55)
            .contentShape(Rectangle())
            .onTapGesture { selection = reminder.id }
            if !last { Divider().padding(.leading, 10) }
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
        guard store.reminders.count < CustomReminder.maxCount else { return }
        let reminder = CustomReminder.suggestion
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
        VStack(spacing: 14) {
            SettingsGroup(title: tr("Reminder", "Нагадування", "Напоминание")) {
                SettingsRow(title: tr("Title", "Назва", "Название")) {
                    TextField("", text: $reminder.title).textFieldStyle(.roundedBorder).frame(width: 220)
                }
                SettingsRow(title: tr("Note", "Примітка", "Заметка")) {
                    TextField("", text: $reminder.note, prompt: Text(tr("Optional", "Необов'язково", "Необязательно")))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(tr("Emoji", "Емодзі", "Эмодзи")).font(.system(size: 13))
                        Spacer()
                        TextField("", text: $reminder.emoji)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                            .frame(width: 48)
                    }
                    HStack(spacing: 2) {
                        ForEach(emojiChoices, id: \.self) { emoji in
                            Button { reminder.emoji = emoji } label: {
                                Text(emoji)
                                    .font(.system(size: 16))
                                    .frame(maxWidth: .infinity, minHeight: 28)
                                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(reminder.emoji == emoji ? tint.opacity(0.3) : Color.primary.opacity(0.03)))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                Divider().padding(.leading, 12)
                SettingsToggle(title: tr("Enabled", "Увімкнено", "Включено"), isOn: $reminder.isEnabled, divider: false)
            }

            SettingsGroup(title: tr("Schedule", "Розклад", "Расписание"),
                          footer: tr("When it pops up you can mark it done, skip it, or push it back by 1 or 2 hours.",
                                     "Коли воно з'явиться, можна натиснути «Готово», пропустити або відкласти на 1–2 години.",
                                     "Когда оно появится, можно нажать «Готово», пропустить или отложить на 1–2 часа.")) {
                Picker("", selection: $reminder.mode) {
                    Text(tr("At set times", "У певний час", "В определённое время")).tag(CustomReminder.Mode.times)
                    Text(tr("Every few hours", "Кожні кілька годин", "Каждые несколько часов")).tag(CustomReminder.Mode.interval)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .padding(10)
                Divider().padding(.leading, 12)

                if reminder.mode == .times {
                    ForEach(Array(reminder.times.enumerated()), id: \.offset) { index, _ in
                        SettingsRow(title: tr("Time \(index + 1)", "Час \(index + 1)", "Время \(index + 1)")) {
                            HStack(spacing: 8) {
                                TimeField(minutes: timeBinding(index))
                                Button {
                                    if reminder.times.indices.contains(index) { reminder.times.remove(at: index) }
                                } label: {
                                    Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                                .disabled(reminder.times.count <= 1)
                            }
                        }
                    }
                    HStack {
                        Button {
                            let last = reminder.times.max() ?? 10 * 60
                            reminder.times.append(min(last + 60, 23 * 60 + 30))
                        } label: {
                            Label(tr("Add a time", "Додати час", "Добавить время"), systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .disabled(reminder.times.count >= CustomReminder.maxTimes)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    Divider().padding(.leading, 12)
                } else {
                    SettingsRow(title: tr("Repeat", "Повтор", "Повтор")) {
                        Picker("", selection: $reminder.intervalMinutes) {
                            ForEach([30, 45, 60, 90, 120, 180, 240], id: \.self) { Text(Clock.everyLabel($0)).tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    SettingsRow(title: tr("From", "З", "С")) { TimeField(minutes: $reminder.startMinute) }
                    SettingsRow(title: tr("Until", "До", "До")) { TimeField(minutes: $reminder.endMinute) }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("Days", "Дні", "Дни")).font(.system(size: 13))
                    WeekdayPicker(selection: $reminder.weekdays, tint: tint, dayWidth: 40)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Button(tr("Show it now", "Показати зараз", "Показать сейчас")) { onPreview() }
                    .buttonStyle(PillButtonStyle(compact: true))
                    .fixedSize()
                Text(reminder.scheduleSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
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
