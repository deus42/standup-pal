import AppKit
import Foundation

/// Keeps settings and progress in step across the user's Macs through the "StandUp Pal"
/// folder in iCloud Drive. It works with the Apple Account already signed in on each
/// Mac: no login, no server. (Apple's iCloud sync APIs need a paid developer account,
/// which an ad-hoc signed open-source build doesn't have; iCloud Drive needs nothing.)
@MainActor
final class CloudSync: ObservableObject {
    static let shared = CloudSync()

    enum Status: Equatable {
        case off
        case unavailable
        case noAccess
        case syncing
        case synced(at: Date, macs: Int)
        case failed(String)
    }

    @Published private(set) var status: Status = .syncing

    /// `STANDUPPAL_SYNC_FOLDER` points sync somewhere else, for testing.
    let folder: URL? = {
        if let override = ProcessInfo.processInfo.environment["STANDUPPAL_SYNC_FOLDER"] {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let drive = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        guard FileManager.default.fileExists(atPath: drive.path) else { return nil }
        return drive.appendingPathComponent("StandUp Pal", isDirectory: true)
    }()

    private let io = DispatchQueue(label: "com.deus.standuppal.sync", qos: .utility)
    private let deviceName = Host.current().localizedName ?? "Mac"
    private var started = false
    private var inFlight = false
    private var again = false
    private var applyingRemote = false
    private var timer: Timer?
    private var pushWork: DispatchWorkItem?
    private var lastWrittenProgress: DeviceProgress?

    private var store: AppStore { AppStore.shared }

    func start() {
        guard !started, !CommandLine.arguments.contains("--snapshot") else { return }
        started = true
        refresh()
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    var isEnabled: Bool { store.syncState.enabled }

    func setEnabled(_ on: Bool) {
        store.syncState.enabled = on
        if on {
            refresh()
        } else {
            status = .off
        }
    }

    /// The user changed something here: upload it shortly.
    func noteLocalChange(settings: Bool, progress: Bool) {
        guard started, !applyingRemote else { return }
        if settings { store.syncState.settingsChangedAt = Date() }
        if progress { store.syncState.progressChangedAt = Date() }
        pushWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.refresh() }
        }
        pushWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    /// Reads what the other Macs wrote, merges it in, then uploads this Mac's side.
    func refresh() {
        guard started else { return }
        Updater.shared.check()
        guard store.syncState.enabled else { status = .off; return }
        guard let folder else { status = .unavailable; return }
        if inFlight { again = true; return }
        inFlight = true
        if case .synced = status {} else { status = .syncing }
        io.async {
            let result = SyncFiles.read(folder)
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self.finishRead(result, folder: folder) }
            }
        }
    }

    func revealInFinder() {
        guard let folder else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }

    private func finishRead(_ result: Result<SyncSnapshot, SyncFiles.Failure>, folder: URL) {
        let snapshot: SyncSnapshot
        switch result {
        case .success(let value):
            snapshot = value
        case .failure(let failure):
            report(failure)
            done()
            return
        }

        let local = SyncSide(settings: store.settings, reminders: store.reminders, pet: store.pet,
                             stats: store.stats, sync: store.syncState)
        let plan = SyncEngine.plan(local, remote: snapshot, deviceName: deviceName, now: Date())

        applyingRemote = true
        if plan.side.settings != store.settings { store.settings = plan.side.settings }
        if plan.side.reminders != store.reminders { store.reminders = plan.side.reminders }
        if plan.side.pet != store.pet { store.pet = plan.side.pet }
        if plan.side.stats != store.stats { store.stats = plan.side.stats }
        store.syncState = plan.side.sync
        applyingRemote = false

        let progress = plan.writeProgress
        let writeProgress = !(lastWrittenProgress.map { $0.sameContent(as: progress) } ?? false)
        let settings = plan.writeSettings
        let macs = plan.macs
        guard settings != nil || writeProgress else {
            status = .synced(at: Date(), macs: macs)
            done()
            return
        }
        io.async {
            var failure: SyncFiles.Failure?
            if let settings { failure = SyncFiles.write(settings, named: SyncFiles.settingsName, in: folder) }
            if failure == nil, writeProgress {
                failure = SyncFiles.write(progress, named: SyncFiles.progressName(progress.deviceID), in: folder)
            }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if let failure {
                        self.report(failure)
                    } else {
                        if writeProgress { self.lastWrittenProgress = progress }
                        self.status = .synced(at: Date(), macs: macs)
                    }
                    self.done()
                }
            }
        }
    }

    private func report(_ failure: SyncFiles.Failure) {
        switch failure {
        case .noAccess: status = .noAccess
        case .other(let message): status = .failed(message)
        }
    }

    private func done() {
        inFlight = false
        if again {
            again = false
            refresh()
        }
    }

    // MARK: Text

    var statusText: String {
        switch status {
        case .off:
            return tr("Sync is off on this Mac.", "Синхронізацію на цьому Mac вимкнено.", "Синхронизация на этом Mac выключена.")
        case .unavailable:
            return tr("Turn on iCloud Drive in System Settings › Apple Account › iCloud.",
                      "Увімкни iCloud Drive: Системні параметри › Apple Account › iCloud.",
                      "Включи iCloud Drive: Системные настройки › Apple Account › iCloud.")
        case .noAccess:
            return tr("Allow access to iCloud Drive in System Settings › Privacy & Security › Files & Folders.",
                      "Дозволь доступ до iCloud Drive: Системні параметри › Конфіденційність і безпека › Файли й папки.",
                      "Разреши доступ к iCloud Drive: Системные настройки › Конфиденциальность и безопасность › Файлы и папки.")
        case .syncing:
            return tr("Syncing…", "Синхронізація…", "Синхронизация…")
        case .synced(let at, let macs):
            let time = Clock.time(at)
            return tr("Up to date · \(time) · Macs: \(macs)", "Синхронізовано · \(time) · Mac: \(macs)",
                      "Синхронизировано · \(time) · Mac: \(macs)")
        case .failed(let message):
            return tr("Couldn't sync: \(message)", "Не вдалося синхронізувати: \(message)", "Не удалось синхронизировать: \(message)")
        }
    }
}
