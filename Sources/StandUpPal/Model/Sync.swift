import Foundation

// Sync between Macs through a folder in iCloud Drive. Settings and reminders are shared
// last-writer-wins; progress is additive: every Mac writes only its own contribution and
// the pet's totals are the sum, so two Macs can never overwrite each other's XP.

/// The shared settings file.
struct SyncedSettings: Codable, Equatable {
    var updatedAt: Date
    var deviceID: String
    /// Changes when progress is reset, so every Mac drops its old contribution.
    var epoch: String
    var settings: AppSettings
    var reminders: [CustomReminder]
}

/// One Mac's own contribution to the pet's progress.
struct DeviceProgress: Codable, Equatable {
    var deviceID: String
    var deviceName: String
    var updatedAt: Date
    var epoch: String
    var pet: PetState
    var stats: [String: DayStats]

    func sameContent(as other: DeviceProgress) -> Bool {
        deviceID == other.deviceID && deviceName == other.deviceName && epoch == other.epoch
            && pet == other.pet && stats == other.stats
    }
}

/// Sync bookkeeping that never leaves this Mac.
struct LocalSyncState: Codable, Equatable {
    var deviceID = UUID().uuidString
    var enabled = true
    var epoch = UUID().uuidString
    var hasSynced = false
    /// Last time the user changed settings or reminders here.
    var settingsChangedAt: Date?
    /// `updatedAt` of the shared settings this Mac last adopted or uploaded.
    var settingsAppliedAt: Date?
    /// Last local change to progress, to decide whose happiness is newer.
    var progressChangedAt: Date?
    /// Other Macs' contributions currently included in the totals.
    var others: [String: DeviceProgress] = [:]
    var lastSync: Date?
}

extension LocalSyncState {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        deviceID = c.value(.deviceID, deviceID)
        enabled = c.value(.enabled, enabled)
        epoch = c.value(.epoch, epoch)
        hasSynced = c.value(.hasSynced, hasSynced)
        settingsChangedAt = c.value(.settingsChangedAt, nil)
        settingsAppliedAt = c.value(.settingsAppliedAt, nil)
        progressChangedAt = c.value(.progressChangedAt, nil)
        others = c.value(.others, others)
        lastSync = c.value(.lastSync, nil)
    }
}

/// Adding and subtracting progress. Counters add up; happiness and best streak don't.
enum ProgressMath {
    private static let dayFields: [WritableKeyPath<DayStats, Int>] = [
        \.standupsDone, \.warmUps, \.skipped, \.snoozed, \.missed, \.away, \.extrasDone, \.extrasSkipped, \.activeSeconds,
        \.eyeBreaks,
    ]
    private static let petFields: [WritableKeyPath<PetState, Int>] = [
        \.xp, \.totalStandups, \.totalWarmUps, \.totalExtras, \.totalEyeBreaks, \.totalBedtimes,
    ]

    static func plus(_ a: DayStats, _ b: DayStats) -> DayStats {
        var r = a
        for f in dayFields { r[keyPath: f] += b[keyPath: f] }
        return r
    }

    static func minus(_ a: DayStats, _ b: DayStats) -> DayStats {
        var r = a
        for f in dayFields { r[keyPath: f] = max(0, a[keyPath: f] - b[keyPath: f]) }
        return r
    }

    static func plus(_ a: [String: DayStats], _ b: [String: DayStats]) -> [String: DayStats] {
        a.merging(b) { plus($0, $1) }
    }

    static func minus(_ a: [String: DayStats], _ b: [String: DayStats]) -> [String: DayStats] {
        var r: [String: DayStats] = [:]
        for (day, value) in a {
            let left = b[day].map { minus(value, $0) } ?? value
            if left != DayStats() { r[day] = left }
        }
        return r
    }

    /// Keeps `a`'s happiness and the larger best streak.
    static func plus(_ a: PetState, _ b: PetState) -> PetState {
        var r = a
        for f in petFields { r[keyPath: f] += b[keyPath: f] }
        r.bestStreak = max(a.bestStreak, b.bestStreak)
        return r
    }

    /// Keeps `a`'s happiness and best streak.
    static func minus(_ a: PetState, _ b: PetState) -> PetState {
        var r = a
        for f in petFields { r[keyPath: f] = max(0, a[keyPath: f] - b[keyPath: f]) }
        return r
    }

    static func total(of devices: [DeviceProgress]) -> (pet: PetState, stats: [String: DayStats]) {
        var pet = PetState(xp: 0, happiness: 0)
        var stats: [String: DayStats] = [:]
        for device in devices {
            pet = plus(pet, device.pet)
            stats = plus(stats, device.stats)
        }
        return (pet, stats)
    }
}

/// The synced parts of one Mac's state.
struct SyncSide: Equatable {
    var settings: AppSettings
    var reminders: [CustomReminder]
    var pet: PetState
    var stats: [String: DayStats]
    var sync: LocalSyncState
}

/// What iCloud Drive currently holds from everyone.
struct SyncSnapshot: Equatable {
    var settings: SyncedSettings?
    var progress: [DeviceProgress] = []
}

struct SyncPlan {
    /// This Mac's state after taking in what the other Macs wrote.
    var side: SyncSide
    var adoptedSettings: Bool
    var writeSettings: SyncedSettings?
    var writeProgress: DeviceProgress
    var macs: Int
}

enum SyncEngine {
    /// One round: take in newer shared settings and the other Macs' progress, then decide
    /// what this Mac uploads. Pure, so it can be tested without iCloud.
    static func plan(_ local: SyncSide, remote: SyncSnapshot, deviceName: String, now: Date) -> SyncPlan {
        var side = local
        var sync = local.sync
        let me = sync.deviceID
        let firstSync = !sync.hasSynced
        var resetOwn = false
        var adopted = false

        if let shared = remote.settings {
            let localStamp = max(sync.settingsChangedAt ?? .distantPast, sync.settingsAppliedAt ?? .distantPast)
            // A new Mac takes the settings already in iCloud instead of overwriting them.
            if (firstSync && shared.deviceID != me) || shared.updatedAt > localStamp {
                if shared.epoch != sync.epoch {
                    resetOwn = !firstSync
                    sync.epoch = shared.epoch
                }
                let settings = shared.settings.keepingLocalChoices(of: side.settings)
                adopted = side.settings != settings || side.reminders != shared.reminders
                side.settings = settings
                side.reminders = shared.reminders
                sync.settingsAppliedAt = shared.updatedAt
            }
        }

        // Rebuild the totals: this Mac's own part plus the other Macs' current parts.
        let oldTotal = ProgressMath.total(of: Array(sync.others.values))
        var latest: [String: DeviceProgress] = [:]
        for device in remote.progress where device.deviceID != me && device.epoch == sync.epoch {
            if let seen = latest[device.deviceID], seen.updatedAt >= device.updatedAt { continue }
            latest[device.deviceID] = device
        }
        let others = Array(latest.values)
        let newTotal = ProgressMath.total(of: others)

        var ownPet = resetOwn ? PetState(xp: 0, happiness: local.pet.happiness) : ProgressMath.minus(local.pet, oldTotal.pet)
        let ownStats = resetOwn ? [:] : ProgressMath.minus(local.stats, oldTotal.stats)
        if resetOwn { ownPet.bestStreak = 0 }

        var pet = ProgressMath.plus(ownPet, newTotal.pet)
        if let newest = others.max(by: { $0.updatedAt < $1.updatedAt }),
           newest.updatedAt > (sync.progressChangedAt ?? .distantPast) {
            pet.happiness = newest.pet.happiness
        }
        side.pet = pet
        side.stats = ProgressMath.plus(ownStats, newTotal.stats)
        sync.others = latest

        var writeSettings: SyncedSettings?
        if remote.settings == nil || (sync.settingsChangedAt ?? .distantPast) > (sync.settingsAppliedAt ?? .distantPast) {
            writeSettings = SyncedSettings(updatedAt: now, deviceID: me, epoch: sync.epoch,
                                           settings: side.settings, reminders: side.reminders)
            sync.settingsAppliedAt = now
        }
        ownPet.happiness = pet.happiness
        ownPet.bestStreak = pet.bestStreak
        let progress = DeviceProgress(deviceID: me, deviceName: deviceName, updatedAt: now, epoch: sync.epoch,
                                      pet: ownPet, stats: ownStats)
        sync.hasSynced = true
        sync.lastSync = now
        side.sync = sync
        return SyncPlan(side: side, adoptedSettings: adopted, writeSettings: writeSettings,
                        writeProgress: progress, macs: others.count + 1)
    }
}

/// Reading and writing the sync folder. Runs off the main thread.
enum SyncFiles {
    static let settingsName = "settings.json"
    static func progressName(_ deviceID: String) -> String { "progress-\(deviceID).json" }

    enum Failure: Error, Equatable {
        case noAccess
        case other(String)
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Everything in the folder. iCloud conflict copies ("settings 2.json") are read too:
    /// the newest settings win, and progress is deduplicated by Mac.
    static func read(_ folder: URL) -> Result<SyncSnapshot, Failure> {
        let fm = FileManager.default
        guard fm.fileExists(atPath: folder.path) else {
            // Touch the parent so a missing permission shows up now, not on the first write.
            do {
                _ = try fm.contentsOfDirectory(atPath: folder.deletingLastPathComponent().path)
                return .success(SyncSnapshot())
            } catch {
                return .failure(failure(error))
            }
        }
        let names: [String]
        do {
            names = try fm.contentsOfDirectory(atPath: folder.path)
        } catch {
            return .failure(failure(error))
        }
        var snapshot = SyncSnapshot()
        for name in names where name.hasSuffix(".json") {
            guard let data = coordinatedRead(folder.appendingPathComponent(name)) else { continue }
            if name.hasPrefix("settings"), let settings = try? decoder.decode(SyncedSettings.self, from: data) {
                if snapshot.settings.map({ $0.updatedAt < settings.updatedAt }) ?? true { snapshot.settings = settings }
            } else if name.hasPrefix("progress-"), let progress = try? decoder.decode(DeviceProgress.self, from: data) {
                snapshot.progress.append(progress)
            }
        }
        return .success(snapshot)
    }

    static func write<T: Encodable>(_ value: T, named name: String, in folder: URL) -> Failure? {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let data = try encoder.encode(value)
            var coordinationError: NSError?
            var writeError: Error?
            NSFileCoordinator().coordinate(writingItemAt: folder.appendingPathComponent(name), options: .forReplacing,
                                           error: &coordinationError) { url in
                do { try data.write(to: url, options: .atomic) } catch { writeError = error }
            }
            if let error = writeError ?? coordinationError { return failure(error) }
            return nil
        } catch {
            return failure(error)
        }
    }

    private static func coordinatedRead(_ url: URL) -> Data? {
        var data: Data?
        var error: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { url in
            data = try? Data(contentsOf: url)
        }
        return data
    }

    private static func failure(_ error: Error) -> Failure {
        let ns = error as NSError
        let denied = (ns.domain == NSCocoaErrorDomain && (ns.code == NSFileReadNoPermissionError || ns.code == NSFileWriteNoPermissionError))
            || (ns.domain == NSPOSIXErrorDomain && (ns.code == Int(EPERM) || ns.code == Int(EACCES)))
        return denied ? .noAccess : .other(ns.localizedDescription)
    }
}
