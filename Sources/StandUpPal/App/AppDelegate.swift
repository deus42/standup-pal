import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let store = AppStore.shared
    private let scheduler = Scheduler.shared
    private let actions = AppActions()

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let reminderPanel = ReminderPanelController()
    private let warmUp = WarmUpController()
    private var settingsWindow: NSWindow?
    private var settingsHeight: CGFloat = 0
    private let settingsNavigation = SettingsNavigation()
    private var cancellables = Set<AnyCancellable>()

    private var iconSignature = ""
    private var lastTitle: String?
    private var iconFrames: [NSImage] = []
    private var iconFrameIndex = 0
    private var iconTimer: Timer?
    /// The preview card currently on screen, if any (not tracked by the scheduler).
    private var previewOccurrence: Occurrence?

    // MARK: Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let id = Bundle.main.bundleIdentifier, !CommandLine.arguments.contains("--snapshot") {
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: id)
                .filter { $0 != NSRunningApplication.current }
            if !others.isEmpty {
                NSApp.terminate(nil)
                return
            }
        }

        installMainMenu()
        wireActions()
        setUpStatusItem()
        setUpPopover()

        scheduler.onPresent = { [weak self] occurrence in self?.present(occurrence) }
        scheduler.onDismiss = { [weak self] in
            guard let self, self.previewOccurrence == nil else { return }
            self.reminderPanel.close()
        }
        scheduler.onRenudge = { [weak self] in self?.reminderPanel.nudge() }
        // @Published fires before the value changes; hop to the next run-loop pass so the
        // icon reflects the finished tick.
        scheduler.$now
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshStatusItem() }
            .store(in: &cancellables)
        store.$settings
            .map { "\($0.petEnabled)\($0.petSpecies)\($0.petColorHex)\($0.petBellyHex)\($0.petHead)\($0.petHands)\($0.petNeck)\($0.showCountdown)\($0.language)" }
            .removeDuplicates()
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.refreshStatusItem(force: true) }
            }
            .store(in: &cancellables)
        store.$settings
            .map(\.language)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.languageDidChange() }
            }
            .store(in: &cancellables)

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)

        scheduler.start()
        refreshStatusItem(force: true)

        if !store.runtime.hasOnboarded {
            store.runtime.hasOnboarded = true
            store.showWelcome = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.showPopover() }
        }
        handleLaunchArguments()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveNow()
    }

    @objc private func systemDidWake() {
        scheduler.tick()
    }

    private func handleLaunchArguments() {
        let args = CommandLine.arguments
        if args.contains("--demo-reminder") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.actions.previewStandup() }
        }
        if args.contains("--demo-extra"), let first = store.reminders.first {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.actions.previewReminder(first) }
        }
        if args.contains("--demo-warmup") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.openWarmUp(nil) }
        }
        if args.contains("--open-settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.openSettings() }
        }
        if args.contains("--open-popover") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.showPopover() }
        }
        if let index = args.firstIndex(of: "--snapshot"), index + 1 < args.count {
            runSnapshots(into: URL(fileURLWithPath: args[index + 1], isDirectory: true))
        }
    }

    // MARK: Actions

    private func wireActions() {
        actions.startWarmUp = { [weak self] in self?.openWarmUp(nil) }
        actions.openSettings = { [weak self] in self?.openSettings() }
        actions.quit = { NSApp.terminate(nil) }
        actions.showHeldNow = { [weak self] in self?.scheduler.showHeldNow() }
        actions.pause = { [weak self] minutes in self?.scheduler.pause(minutes: minutes) }
        actions.pauseUntilTomorrow = { [weak self] in self?.scheduler.pauseUntilTomorrow() }
        actions.resume = { [weak self] in self?.scheduler.resume() }
        actions.petTapped = { [weak self] in
            guard let self else { return }
            self.store.showWelcome = false
            self.store.react(.happy, for: 2.5)
            SoundPlayer.shared.play(.boop)
        }
        actions.previewStandup = { [weak self] in
            let now = Date()
            self?.showPreview(Occurrence(id: "preview-\(UUID().uuidString)", kind: .standup,
                                         scheduled: now, due: now, isPreview: true))
        }
        actions.previewReminder = { [weak self] reminder in
            let now = Date()
            self?.showPreview(Occurrence(id: "preview-\(UUID().uuidString)", kind: .custom(reminder.id),
                                         scheduled: now, due: now, isPreview: true))
        }
    }

    private func present(_ occurrence: Occurrence) {
        previewOccurrence = nil
        reminderPanel.show(occurrence: occurrence) { [weak self] action in
            self?.handle(action, for: occurrence)
        }
    }

    private func showPreview(_ occurrence: Occurrence) {
        guard scheduler.active == nil else { return }
        popover.performClose(nil)
        previewOccurrence = occurrence
        reminderPanel.show(occurrence: occurrence) { [weak self] action in
            self?.handle(action, for: occurrence)
        }
        SoundPlayer.shared.play(.reminder)
    }

    private func handle(_ action: ReminderAction, for occurrence: Occurrence) {
        if occurrence.isPreview {
            previewOccurrence = nil
            reminderPanel.close()
            if case .warmUp = action { openWarmUp(nil) }
            return
        }
        switch action {
        case .warmUp:
            reminderPanel.close()
            openWarmUp(occurrence)
        case .stoodUp:
            scheduler.resolve(occurrence, .stoodUp)
        case .done:
            scheduler.resolve(occurrence, .done)
        case .snooze(let minutes):
            scheduler.snooze(occurrence, minutes: minutes)
        case .skip:
            scheduler.resolve(occurrence, .skipped)
        }
        reminderPanel.close()
    }

    private func openWarmUp(_ occurrence: Occurrence?) {
        popover.performClose(nil)
        if previewOccurrence != nil {
            previewOccurrence = nil
            reminderPanel.close()
        }
        warmUp.onClose = { [weak self] in
            guard let self, self.settingsWindow?.isVisible != true else { return }
            NSApp.deactivate()
        }
        warmUp.open(occurrence: occurrence)
    }

    // MARK: Status item

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageLeading
        button.toolTip = statusToolTip
    }

    private var statusToolTip: String {
        tr("StandUp Pal: click for your pet, right-click for options",
           "StandUp Pal: клацни — улюбленець, правий клік — меню",
           "StandUp Pal: клик — питомец, правый клик — меню")
    }

    private func languageDidChange() {
        installMainMenu()
        statusItem.button?.toolTip = statusToolTip
        settingsWindow?.title = settingsTitle
        refreshStatusItem(force: true)
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func refreshStatusItem(force: Bool = false) {
        guard let button = statusItem?.button else { return }
        let s = store.settings
        let now = scheduler.now
        let mood = scheduler.petMood(at: now)
        let signature = "\(s.petEnabled)|\(mood.rawValue)|\(PetLook.from(s))"
        if force || signature != iconSignature {
            iconSignature = signature
            rebuildIcon(mood: mood)
        }
        let text = s.showCountdown ? statusText(now) : ""
        if force || text != lastTitle {
            lastTitle = text
            button.attributedTitle = NSAttributedString(
                string: text.isEmpty ? "" : " \(text)",
                attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .medium)])
        }
    }

    private func statusText(_ now: Date) -> String {
        if scheduler.active != nil { return tr("Now!", "Зараз!", "Сейчас!") }
        if scheduler.holdReason != nil, !scheduler.queue.isEmpty { return tr("Later", "Пізніше", "Позже") }
        if scheduler.isPaused(now) { return tr("Paused", "Пауза", "Пауза") }
        guard let next = scheduler.nextStandup else { return "" }
        let seconds = next.timeIntervalSince(now)
        // Keep the menu bar clean overnight and on weekends.
        if seconds > 3 * 3600 { return "" }
        return Clock.shortCountdown(seconds)
    }

    private func rebuildIcon(mood: PetMood) {
        iconTimer?.invalidate()
        iconTimer = nil
        guard let button = statusItem.button else { return }
        let s = store.settings

        guard s.petEnabled else {
            let name: String
            switch mood {
            case .alert: name = "figure.wave"
            case .sleepy: name = "moon.zzz"
            default: name = "figure.stand"
            }
            let image = NSImage(systemSymbolName: name, accessibilityDescription: "StandUp Pal")
                ?? NSImage(systemSymbolName: "figure.stand", accessibilityDescription: "StandUp Pal")
            image?.isTemplate = true
            button.image = image
            return
        }

        let look = PetLook.from(s)
        if mood == .alert {
            iconFrames = (0..<8).compactMap { PetIcon.image(look: look, mood: .alert, t: Double($0) / 16) }
            iconFrameIndex = 0
            button.image = iconFrames.first
            let timer = Timer(timeInterval: 1.0 / 16.0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.advanceIconFrame() }
            }
            RunLoop.main.add(timer, forMode: .common)
            iconTimer = timer
        } else {
            let t: Double = (mood == .happy || mood == .celebrate) ? 0.16 : 0
            button.image = PetIcon.image(look: look, mood: mood, t: t)
        }
    }

    private func advanceIconFrame() {
        guard !iconFrames.isEmpty else { return }
        iconFrameIndex = (iconFrameIndex + 1) % iconFrames.count
        statusItem.button?.image = iconFrames[iconFrameIndex]
    }

    // MARK: Popover

    private func setUpPopover() {
        let hosting = NSHostingController(
            rootView: PopoverView(actions: actions)
                .environmentObject(store)
                .environmentObject(scheduler))
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.animates = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(popoverDidClose), name: NSPopover.didCloseNotification, object: popover)
    }

    @objc private func popoverDidClose() {
        store.showWelcome = false
        // Hand focus back to whatever you were doing, unless one of our windows is up.
        if settingsWindow?.isVisible != true, !warmUp.isOpen {
            NSApp.deactivate()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    // MARK: Right-click menu

    private func showMenu() {
        popover.performClose(nil)
        statusItem.menu = buildMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let s = store.settings
        let now = Date()

        let header = NSMenuItem(title: menuHeader(now), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(item(tr("Start warm-up now", "Почати розминку зараз", "Начать разминку сейчас"), #selector(menuStartWarmUp)))
        menu.addItem(.separator())

        menu.addItem(check(tr("Sound", "Звук", "Звук"), s.soundEnabled, #selector(menuToggleSound)))
        menu.addItem(check(tr("Pet", "Улюбленець", "Питомец"), s.petEnabled, #selector(menuTogglePet)))
        menu.addItem(check(tr("Show countdown", "Показувати відлік", "Показывать отсчёт"), s.showCountdown, #selector(menuToggleCountdown)))

        let paused = scheduler.isPaused(now)
        let until = Clock.time(store.runtime.pausedUntil ?? now)
        let pauseItem = NSMenuItem(title: paused ? tr("Paused until \(until)", "Пауза до \(until)", "Пауза до \(until)")
                                                 : tr("Pause reminders", "Призупинити нагадування", "Приостановить напоминания"),
                                   action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        if paused {
            submenu.addItem(item(tr("Resume now", "Продовжити зараз", "Продолжить сейчас"), #selector(menuResume)))
            submenu.addItem(.separator())
        }
        let choices = [(Words.minutesLong(30), 30), (Words.hours(1), 60), (Words.hours(2), 120),
                       (tr("Until tomorrow", "До завтра", "До завтра"), -1)]
        for (title, minutes) in choices {
            let entry = item(title, #selector(menuPause(_:)))
            entry.tag = minutes
            submenu.addItem(entry)
        }
        pauseItem.submenu = submenu
        menu.addItem(pauseItem)

        let languageItem = NSMenuItem(title: tr("Language", "Мова", "Язык"), action: nil, keyEquivalent: "")
        let languages = NSMenu()
        for language in AppLanguage.allCases {
            let entry = check(language.nativeName, s.language == language, #selector(menuLanguage(_:)))
            entry.representedObject = language.rawValue
            languages.addItem(entry)
        }
        languageItem.submenu = languages
        menu.addItem(languageItem)

        menu.addItem(.separator())
        menu.addItem(item(tr("Settings…", "Налаштування…", "Настройки…"), #selector(menuOpenSettings), key: ","))
        menu.addItem(item(tr("Quit StandUp Pal", "Вийти з StandUp Pal", "Выйти из StandUp Pal"), #selector(menuQuit), key: "q"))
        return menu
    }

    private func menuHeader(_ now: Date) -> String {
        if scheduler.active != nil { return tr("Stand-up time!", "Час перерви!", "Время перерыва!") }
        if let next = scheduler.nextStandup {
            let sameDay = Clock.calendar.isDate(next, inSameDayAs: now)
            let when = sameDay ? Clock.time(next) : Clock.dayAndTime(next, wide: false)
            return tr("Next stand-up: \(when)", "Наступна перерва: \(when)", "Следующий перерыв: \(when)")
        }
        return tr("No stand-ups scheduled", "Перерв не заплановано", "Перерывов не запланировано")
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
        entry.target = self
        return entry
    }

    private func check(_ title: String, _ on: Bool, _ action: Selector) -> NSMenuItem {
        let entry = item(title, action)
        entry.state = on ? .on : .off
        return entry
    }

    @objc private func menuStartWarmUp() { openWarmUp(nil) }
    @objc private func menuToggleSound() { store.settings.soundEnabled.toggle() }
    @objc private func menuTogglePet() { store.settings.petEnabled.toggle() }
    @objc private func menuToggleCountdown() { store.settings.showCountdown.toggle() }
    @objc private func menuResume() { scheduler.resume() }
    @objc private func menuQuit() { NSApp.terminate(nil) }
    @objc func menuOpenSettings() { openSettings() }
    @objc func menuOpenAbout() { openSettings(tab: .about) }

    @objc private func menuLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let language = AppLanguage(rawValue: raw) else { return }
        store.settings.language = language
    }

    @objc private func menuPause(_ sender: NSMenuItem) {
        if sender.tag < 0 {
            scheduler.pauseUntilTomorrow()
        } else {
            scheduler.pause(minutes: sender.tag)
        }
    }

    // MARK: Settings window

    private func openSettings(tab: SettingsTab? = nil) {
        popover.performClose(nil)
        if let tab { settingsNavigation.tab = tab }
        if settingsWindow == nil {
            let hosting = NSHostingController(
                rootView: SettingsView(navigation: settingsNavigation, actions: actions,
                                       onHeight: { [weak self] height in self?.fitSettingsWindow(to: height) })
                    .environmentObject(store)
                    .environmentObject(scheduler))
            hosting.sizingOptions = []
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: SettingsView.width, height: 560),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.contentViewController = hosting
            window.setContentSize(NSSize(width: SettingsView.width, height: 560))
            window.title = settingsTitle
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private var settingsTitle: String {
        tr("StandUp Pal Settings", "Налаштування StandUp Pal", "Настройки StandUp Pal")
    }

    /// Sizes the settings window to the visible tab, keeping its top edge in place, so no
    /// tab ever needs a scroll bar.
    private func fitSettingsWindow(to height: CGFloat) {
        guard let window = settingsWindow, height > 0, abs(height - settingsHeight) > 0.5 else { return }
        let animate = window.isVisible && settingsHeight > 0
        settingsHeight = height
        let content = NSRect(x: 0, y: 0, width: SettingsView.width, height: ceil(height))
        var frame = window.frameRect(forContentRect: content)
        frame.origin.x = window.frame.minX
        frame.origin.y = window.frame.maxY - frame.height
        if let screen = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame, frame.minY < screen.minY {
            frame.origin.y = max(screen.minY, screen.maxY - frame.height)
        }
        window.setFrame(frame, display: true, animate: animate)
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === settingsWindow else { return }
        store.saveNow()
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: Main menu (keyboard shortcuts in text fields need an Edit menu)

    private func installMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: tr("About StandUp Pal", "Про StandUp Pal", "О StandUp Pal"), action: #selector(menuOpenAbout), keyEquivalent: "")
        appMenu.addItem(withTitle: tr("Settings…", "Налаштування…", "Настройки…"), action: #selector(menuOpenSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: tr("Hide StandUp Pal", "Сховати StandUp Pal", "Скрыть StandUp Pal"),
                        action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: tr("Quit StandUp Pal", "Вийти з StandUp Pal", "Выйти из StandUp Pal"),
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: tr("Edit", "Правка", "Правка"))
        edit.addItem(withTitle: tr("Undo", "Скасувати", "Отменить"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: tr("Redo", "Повторити", "Повторить"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: tr("Cut", "Вирізати", "Вырезать"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: tr("Copy", "Копіювати", "Копировать"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: tr("Paste", "Вставити", "Вставить"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: tr("Select All", "Вибрати все", "Выбрать всё"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: tr("Window", "Вікно", "Окно"))
        windowMenu.addItem(withTitle: tr("Close", "Закрити", "Закрыть"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: tr("Minimize", "Згорнути", "Свернуть"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)

        NSApp.mainMenu = main
    }
}

// MARK: Debug snapshots

extension AppDelegate {
    /// `--showcase`: a lived-in demo for screenshots. Only ever runs on the separate
    /// snapshot defaults suite.
    fileprivate func applyShowcaseState() {
        var s = store.settings
        s.workStartMinute = 0
        s.workEndMinute = 24 * 60 - 1
        s.workDays = Set(1...7)
        s.petName = "Pip"
        s.petSpecies = .blob
        s.petColorHex = "#7ED6B2"
        s.petBellyHex = "#E4F8EF"
        s.petHead = .sweatband
        s.petHands = .dumbbells
        s.petNeck = .medal
        s.soundEnabled = true
        store.settings = s
        store.pet = PetState(xp: 1420, happiness: 92, totalStandups: 214, totalWarmUps: 131, totalExtras: 58, bestStreak: 9)
        var stats: [String: DayStats] = [:]
        for (offset, done) in [6, 7, 6, 8, 6, 4, 6, 7, 5, 6, 8, 6, 3, 6].enumerated() {
            let day = Clock.addDays(-(offset + 1), to: Date())
            stats[Clock.dayKey(day)] = DayStats(standupsDone: done, warmUps: max(0, done - 2), extrasDone: done / 3, activeSeconds: done * 150)
        }
        stats[store.todayKey] = DayStats(standupsDone: 5, warmUps: 4, snoozed: 1, extrasDone: 2, activeSeconds: 760)
        store.stats = stats
        store.runtime.hasOnboarded = true
        store.showWelcome = false
        store.toast = nil
        // Nothing real may be on screen while the previews are captured.
        let soon = Date().addingTimeInterval(60)
        store.runtime.firedIDs.formUnion(scheduler.occurrences(on: Date()).filter { $0.due <= soon }.map(\.id))
        scheduler.pause(minutes: 1)
        scheduler.resume()
    }

    /// `--snapshot <dir>` renders the app's real windows to PNG files from inside the
    /// process (no screen-recording permission needed), then quits. Used to check the UI.
    fileprivate func runSnapshots(into directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        func shot(_ view: NSView?, _ name: String, background: NSColor = .windowBackgroundColor) {
            guard let view, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: rep)
            // cacheDisplay skips window chrome and vibrancy, so paint the backdrop ourselves.
            let image = NSImage(size: view.bounds.size)
            image.lockFocus()
            view.effectiveAppearance.performAsCurrentDrawingAppearance {
                background.setFill()
                NSRect(origin: .zero, size: view.bounds.size).fill()
            }
            rep.draw(in: NSRect(origin: .zero, size: view.bounds.size), from: .zero, operation: .sourceOver,
                     fraction: 1, respectFlipped: true, hints: nil)
            image.unlockFocus()
            guard let tiff = image.tiffRepresentation, let out = NSBitmapImageRep(data: tiff) else { return }
            try? out.representation(using: .png, properties: [:])?.write(to: directory.appendingPathComponent("\(name).png"))
        }
        func wait(_ seconds: Double) async {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }

        SoundPlayer.shared.isMuted = true
        if CommandLine.arguments.contains("--showcase") { applyShowcaseState() }
        Task { @MainActor in
            let languages: [AppLanguage] = CommandLine.arguments.contains("--all-languages") ? [.en, .uk, .ru] : [store.settings.language]
            for language in languages {
                store.settings.language = language
                let prefix = languages.count > 1 ? "\(language.rawValue)-" : ""
                await wait(1.2)
                shot(statusItem.button, "\(prefix)0-menu-bar", background: .controlBackgroundColor)
                showPopover()
                await wait(1.2)
                shot(popover.contentViewController?.view, "\(prefix)1-popover")
                popover.performClose(nil)

                actions.previewStandup()
                await wait(1.2)
                shot(reminderPanel.contentView, "\(prefix)2-standup-card")
                handle(.skip, for: previewOccurrence ?? Occurrence(id: "preview-x", kind: .standup, scheduled: Date(), due: Date(), isPreview: true))

                if let first = store.reminders.first {
                    actions.previewReminder(first)
                    await wait(1.2)
                    shot(reminderPanel.contentView, "\(prefix)3-extra-card")
                    handle(.skip, for: previewOccurrence ?? Occurrence(id: "preview-y", kind: .custom(first.id), scheduled: Date(), due: Date(), isPreview: true))
                }

                openWarmUp(nil)
                await wait(1.2)
                shot(warmUp.contentView, "\(prefix)4-warmup-get-ready")
                await wait(3.6)
                shot(warmUp.contentView, "\(prefix)5-warmup-exercise")
                warmUp.finishNow()
                await wait(1.5)
                shot(warmUp.contentView, "\(prefix)6-warmup-finished")
                warmUp.close()

                for (index, tab) in SettingsTab.allCases.enumerated() {
                    openSettings(tab: tab)
                    await wait(1.0)
                    shot(settingsWindow?.contentView, "\(prefix)7-settings-\(index + 1)-\(tab.rawValue)")
                }
                settingsWindow?.close()
            }
            await wait(0.5)
            NSApp.terminate(nil)
        }
    }
}
