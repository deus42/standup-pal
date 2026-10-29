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
        if let id = Bundle.main.bundleIdentifier {
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
            .map { "\($0.petEnabled)\($0.petSpecies)\($0.petColorHex)\($0.petAccessory)\($0.showCountdown)" }
            .removeDuplicates()
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.refreshStatusItem(force: true) }
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
        button.toolTip = "StandUp Pal: click for your pet, right-click for options"
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
        let signature = "\(s.petEnabled)|\(mood.rawValue)|\(s.petSpecies.rawValue)|\(s.petColorHex)|\(s.petAccessory.rawValue)"
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
        if scheduler.active != nil { return "Now!" }
        if scheduler.holdReason != nil, !scheduler.queue.isEmpty { return "Later" }
        if scheduler.isPaused(now) { return "Paused" }
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
        menu.addItem(item("Start warm-up now", #selector(menuStartWarmUp)))
        menu.addItem(.separator())

        menu.addItem(check("Sound", s.soundEnabled, #selector(menuToggleSound)))
        menu.addItem(check("Pet", s.petEnabled, #selector(menuTogglePet)))
        menu.addItem(check("Show countdown", s.showCountdown, #selector(menuToggleCountdown)))

        let paused = scheduler.isPaused(now)
        let pauseItem = NSMenuItem(title: paused ? "Paused until \(Clock.time(store.runtime.pausedUntil ?? now))" : "Pause reminders",
                                   action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        if paused {
            submenu.addItem(item("Resume now", #selector(menuResume)))
            submenu.addItem(.separator())
        }
        for (title, minutes) in [("30 minutes", 30), ("1 hour", 60), ("2 hours", 120), ("Until tomorrow", -1)] {
            let entry = item(title, #selector(menuPause(_:)))
            entry.tag = minutes
            submenu.addItem(entry)
        }
        pauseItem.submenu = submenu
        menu.addItem(pauseItem)

        menu.addItem(.separator())
        menu.addItem(item("Settings…", #selector(menuOpenSettings), key: ","))
        menu.addItem(item("Quit StandUp Pal", #selector(menuQuit), key: "q"))
        return menu
    }

    private func menuHeader(_ now: Date) -> String {
        if scheduler.active != nil { return "Stand-up time!" }
        if let next = scheduler.nextStandup {
            let sameDay = Clock.calendar.isDate(next, inSameDayAs: now)
            let when = sameDay ? Clock.time(next) : next.formatted(.dateTime.weekday(.abbreviated).hour().minute())
            return "Next stand-up: \(when)"
        }
        return "No stand-ups scheduled"
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
                rootView: SettingsView(navigation: settingsNavigation, actions: actions)
                    .environmentObject(store)
                    .environmentObject(scheduler))
            let window = NSWindow(contentViewController: hosting)
            window.title = "StandUp Pal"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
        appMenu.addItem(withTitle: "About StandUp Pal", action: #selector(menuOpenAbout), keyEquivalent: "")
        appMenu.addItem(withTitle: "Settings…", action: #selector(menuOpenSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide StandUp Pal", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit StandUp Pal", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)

        NSApp.mainMenu = main
    }
}

// MARK: Debug snapshots

extension AppDelegate {
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

        Task { @MainActor in
            await wait(1.2)
            shot(statusItem.button, "0-menu-bar", background: .controlBackgroundColor)
            showPopover()
            await wait(1.2)
            shot(popover.contentViewController?.view, "1-popover")
            popover.performClose(nil)

            actions.previewStandup()
            await wait(1.2)
            shot(reminderPanel.contentView, "2-standup-card")
            handle(.skip, for: previewOccurrence ?? Occurrence(id: "preview-x", kind: .standup, scheduled: Date(), due: Date(), isPreview: true))

            if let first = store.reminders.first {
                actions.previewReminder(first)
                await wait(1.2)
                shot(reminderPanel.contentView, "3-extra-card")
                handle(.skip, for: previewOccurrence ?? Occurrence(id: "preview-y", kind: .custom(first.id), scheduled: Date(), due: Date(), isPreview: true))
            }

            openWarmUp(nil)
            await wait(1.2)
            shot(warmUp.contentView, "4-warmup-get-ready")
            await wait(3.6)
            shot(warmUp.contentView, "5-warmup-exercise")
            warmUp.finishNow()
            await wait(1.5)
            shot(warmUp.contentView, "6-warmup-finished")
            warmUp.close()

            for (index, tab) in SettingsTab.allCases.enumerated() {
                openSettings(tab: tab)
                await wait(1.0)
                shot(settingsWindow?.contentView, "7-settings-\(index + 1)-\(tab.rawValue)")
            }
            await wait(0.5)
            NSApp.terminate(nil)
        }
    }
}
