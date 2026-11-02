import AppKit
import CryptoKit
import Foundation
import Security

/// What `build-app.sh --publish-update` writes to `iCloud Drive/StandUp Pal/Updates/latest.json`.
struct UpdateManifest: Codable, Equatable {
    var version: String
    var build: Int
    var file: String
    var sha256: String
    var date: Date?

    func isNewer(than build: Int) -> Bool { self.build > build }

    static func decode(_ data: Data) -> UpdateManifest? {
        try? SyncFiles.decoder.decode(UpdateManifest.self, from: data)
    }
}

/// One-click updates between your own Macs: a new build appears in iCloud Drive, the app
/// checks it is signed with the same certificate as itself, swaps itself and relaunches.
/// No network and no GitHub involved.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    enum State: Equatable {
        case idle
        case installing
        case failed(String)
    }

    @Published private(set) var available: UpdateManifest?
    @Published private(set) var state: State = .idle

    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    let currentBuild = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
    /// Ad-hoc builds can't prove an update comes from the same author, so they don't self-update.
    let canSelfUpdate: Bool = Updater.signingRequirement() != nil

    private let io = DispatchQueue(label: "com.deus.standuppal.updates", qos: .utility)
    private var checking = false

    private var folder: URL? { CloudSync.shared.folder?.appendingPathComponent("Updates", isDirectory: true) }

    func check() {
        guard !checking, state != .installing, let folder, currentBuild > 0 else { return }
        checking = true
        let current = currentBuild
        io.async {
            let manifest = (try? Data(contentsOf: folder.appendingPathComponent("latest.json"))).flatMap(UpdateManifest.decode)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.checking = false
                    let newer = manifest.flatMap { $0.isNewer(than: current) ? $0 : nil }
                    if newer != self.available { self.available = newer }
                }
            }
        }
    }

    func revealUpdates() {
        guard let folder else { return }
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }

    func install() {
        guard let manifest = available, let folder, state != .installing else { return }
        guard canSelfUpdate, let requirement = Self.signingRequirement() else {
            revealUpdates()
            return
        }
        state = .installing
        let appURL = Bundle.main.bundleURL
        io.async {
            let result = Self.prepare(manifest, from: folder, requirement: requirement)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    switch result {
                    case .success(let newApp): self.swap(appURL, with: newApp)
                    case .failure(let error): self.state = .failed(error.message)
                    }
                }
            }
        }
    }

    // MARK: Install steps

    struct Failure: Error { let message: String }

    /// Copies, checks and unpacks the update. Runs off the main thread.
    nonisolated private static func prepare(_ manifest: UpdateManifest, from folder: URL,
                                            requirement: SecRequirement) -> Result<URL, Failure> {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("standuppal-update-\(UUID().uuidString)", isDirectory: true)
        do {
            try fm.createDirectory(at: work, withIntermediateDirectories: true)
            let zip = work.appendingPathComponent(manifest.file)
            try fm.copyItem(at: folder.appendingPathComponent(manifest.file), to: zip)
            let digest = SHA256.hash(data: try Data(contentsOf: zip)).map { String(format: "%02x", $0) }.joined()
            guard digest == manifest.sha256.lowercased() else {
                return .failure(Failure(message: tr("The download is damaged.", "Файл оновлення пошкоджено.", "Файл обновления повреждён.")))
            }
            let unzip = Process()
            unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            unzip.arguments = ["-x", "-k", zip.path, work.path]
            try unzip.run()
            unzip.waitUntilExit()
            let newApp = work.appendingPathComponent("StandUp Pal.app")
            guard unzip.terminationStatus == 0, fm.fileExists(atPath: newApp.path) else {
                return .failure(Failure(message: tr("Couldn't unpack the update.", "Не вдалося розпакувати оновлення.",
                                                    "Не удалось распаковать обновление.")))
            }
            guard isSigned(newApp, satisfying: requirement) else {
                return .failure(Failure(message: tr("The update isn't signed like this app, so it wasn't installed.",
                                                    "Оновлення підписане не так, як цей застосунок, тому його не встановлено.",
                                                    "Обновление подписано не так, как это приложение, поэтому оно не установлено.")))
            }
            return .success(newApp)
        } catch {
            return .failure(Failure(message: error.localizedDescription))
        }
    }

    /// Moves the old app to the Trash, puts the new one in its place and relaunches.
    private func swap(_ appURL: URL, with newApp: URL) {
        let fm = FileManager.default
        AppStore.shared.saveNow()
        do {
            try fm.trashItem(at: appURL, resultingItemURL: nil)
            try fm.moveItem(at: newApp, to: appURL)
        } catch {
            state = .failed(error.localizedDescription)
            return
        }
        let pid = ProcessInfo.processInfo.processIdentifier
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", "while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$0\"", appURL.path]
        do {
            try relaunch.run()
        } catch {
            state = .failed(error.localizedDescription)
            return
        }
        NSApp.terminate(nil)
    }

    // MARK: Code signing

    /// This app's designated requirement when it is signed with a certificate; nil when ad-hoc.
    nonisolated static func signingRequirement() -> SecRequirement? {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var requirement: SecRequirement?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopyDesignatedRequirement(staticCode, [], &requirement) == errSecSuccess, let requirement else {
            return nil
        }
        var text: CFString?
        SecRequirementCopyString(requirement, [], &text)
        // Ad-hoc signatures pin the exact binary ("cdhash"), which no update can match.
        guard let text = text as String?, text.contains("certificate") else { return nil }
        return requirement
    }

    nonisolated static func isSigned(_ app: URL, satisfying requirement: SecRequirement) -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code else { return false }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        return SecStaticCodeCheckValidity(code, flags, requirement) == errSecSuccess
    }

    // MARK: Text

    var bannerTitle: String {
        guard let available else { return "" }
        return tr("Version \(available.version) is ready", "Готова версія \(available.version)", "Готова версия \(available.version)")
    }

    var buttonTitle: String {
        if state == .installing { return tr("Updating…", "Оновлення…", "Обновление…") }
        return canSelfUpdate ? tr("Update", "Оновити", "Обновить") : tr("Show", "Показати", "Показать")
    }
}
