import Foundation
import Testing
@testable import StandUpPal

/// Two simulated Macs exchanging files through a shared snapshot, the way iCloud Drive would.
@Suite("iCloud sync")
struct SyncTests {
    private struct Mac {
        var side: SyncSide
        let name: String

        init(name: String, pet: PetState = PetState(), stats: [String: DayStats] = [:], settings: AppSettings = AppSettings()) {
            self.name = name
            side = SyncSide(settings: settings, reminders: CustomReminder.defaults, pet: pet, stats: stats, sync: LocalSyncState())
        }

        /// One sync round against the shared folder.
        mutating func sync(_ cloud: inout SyncSnapshot, at now: Date) -> SyncPlan {
            let plan = SyncEngine.plan(side, remote: cloud, deviceName: name, now: now)
            side = plan.side
            if let settings = plan.writeSettings { cloud.settings = settings }
            cloud.progress.removeAll { $0.deviceID == plan.writeProgress.deviceID }
            cloud.progress.append(plan.writeProgress)
            return plan
        }

        mutating func earn(xp: Int, standups: Int = 0, day: String) {
            side.pet.xp += xp
            side.pet.totalStandups += standups
            side.stats[day, default: DayStats()].standupsDone += standups
        }

        mutating func edit(_ change: (inout AppSettings) -> Void, at time: Date) {
            change(&side.settings)
            side.sync.settingsChangedAt = time
        }
    }

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private func t(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

    @Test func progressMathAddsCountersAndNeverGoesNegative() {
        let a = DayStats(standupsDone: 3, warmUps: 1, activeSeconds: 200)
        let b = DayStats(standupsDone: 1, warmUps: 2, activeSeconds: 50)
        #expect(ProgressMath.plus(a, b) == DayStats(standupsDone: 4, warmUps: 3, activeSeconds: 250))
        #expect(ProgressMath.minus(a, b) == DayStats(standupsDone: 2, warmUps: 0, activeSeconds: 150))
        #expect(ProgressMath.minus(["d": b], ["d": b]).isEmpty)
        let pet = ProgressMath.plus(PetState(xp: 10, happiness: 80, bestStreak: 2), PetState(xp: 5, happiness: 10, bestStreak: 4))
        #expect(pet.xp == 15 && pet.happiness == 80 && pet.bestStreak == 4)
    }

    @Test func aNewMacTakesTheExistingSettingsAndProgress() {
        var cloud = SyncSnapshot()
        var settingsA = AppSettings()
        settingsA.petSpecies = .dino
        settingsA.language = .uk
        var a = Mac(name: "MacBook Pro", pet: PetState(xp: 190, happiness: 96, totalStandups: 8),
                    stats: ["2026-11-02": DayStats(standupsDone: 3)], settings: settingsA)
        var b = Mac(name: "MacBook Air")

        let first = a.sync(&cloud, at: t(0))
        #expect(first.writeSettings != nil)
        #expect(cloud.progress.first?.pet.xp == 190)

        let second = b.sync(&cloud, at: t(1))
        #expect(second.writeSettings == nil, "a newcomer must not overwrite the shared settings")
        #expect(second.adoptedSettings)
        #expect(b.side.settings.petSpecies == .dino && b.side.settings.language == .uk)
        #expect(b.side.pet.xp == 190 && b.side.pet.totalStandups == 8)
        #expect(b.side.stats["2026-11-02"]?.standupsDone == 3)
        #expect(second.writeProgress.pet.xp == 0, "the newcomer has contributed nothing yet")
        #expect(second.macs == 2)
    }

    @Test func progressFromBothMacsAddsUpWithoutDoubleCounting() {
        var cloud = SyncSnapshot()
        var a = Mac(name: "A", pet: PetState(xp: 100))
        var b = Mac(name: "B")
        _ = a.sync(&cloud, at: t(0))
        _ = b.sync(&cloud, at: t(1))

        b.earn(xp: 25, standups: 1, day: "d1")
        _ = b.sync(&cloud, at: t(2))
        a.earn(xp: 15, standups: 1, day: "d1")
        _ = a.sync(&cloud, at: t(3))
        _ = b.sync(&cloud, at: t(4))
        _ = a.sync(&cloud, at: t(5))
        // Repeated rounds must stay stable.
        _ = b.sync(&cloud, at: t(6))
        _ = a.sync(&cloud, at: t(7))

        #expect(a.side.pet.xp == 140 && b.side.pet.xp == 140)
        #expect(a.side.stats["d1"]?.standupsDone == 2 && b.side.stats["d1"]?.standupsDone == 2)
        let contributions = Dictionary(uniqueKeysWithValues: cloud.progress.map { ($0.deviceName, $0.pet.xp) })
        #expect(contributions == ["A": 115, "B": 25])
    }

    @Test func theLatestSettingsChangeWins() {
        var cloud = SyncSnapshot()
        var a = Mac(name: "A")
        var b = Mac(name: "B")
        _ = a.sync(&cloud, at: t(0))
        _ = b.sync(&cloud, at: t(1))

        b.edit({ $0.dailyGoal = 9 }, at: t(2))
        #expect(b.sync(&cloud, at: t(3)).writeSettings?.settings.dailyGoal == 9)
        let plan = a.sync(&cloud, at: t(4))
        #expect(plan.adoptedSettings && a.side.settings.dailyGoal == 9)
        #expect(plan.writeSettings == nil)

        a.edit({ $0.petName = "Rex" }, at: t(5))
        _ = a.sync(&cloud, at: t(6))
        _ = b.sync(&cloud, at: t(7))
        #expect(b.side.settings.petName == "Rex" && b.side.settings.dailyGoal == 9)
    }

    @Test func resettingProgressOnOneMacResetsItEverywhere() {
        var cloud = SyncSnapshot()
        var a = Mac(name: "A", pet: PetState(xp: 300))
        var b = Mac(name: "B")
        _ = a.sync(&cloud, at: t(0))
        _ = b.sync(&cloud, at: t(1))
        b.earn(xp: 40, day: "d1")
        _ = b.sync(&cloud, at: t(2))

        // What AppStore.resetProgress does on Mac A.
        a.side.sync.epoch = UUID().uuidString
        a.side.sync.others = [:]
        a.side.sync.settingsChangedAt = t(3)
        a.side.pet = PetState()
        a.side.stats = [:]
        _ = a.sync(&cloud, at: t(4))
        _ = b.sync(&cloud, at: t(5))
        _ = a.sync(&cloud, at: t(6))

        #expect(a.side.pet.xp == 0 && b.side.pet.xp == 0)
        #expect(b.side.stats.isEmpty)
        #expect(a.side.sync.epoch == b.side.sync.epoch)
    }

    @Test func happinessFollowsTheMacThatChangedItLast() {
        var cloud = SyncSnapshot()
        var a = Mac(name: "A", pet: PetState(xp: 0, happiness: 50))
        var b = Mac(name: "B")
        _ = a.sync(&cloud, at: t(0))
        _ = b.sync(&cloud, at: t(1))
        #expect(b.side.pet.happiness == 50)
        b.side.pet.happiness = 90
        b.side.sync.progressChangedAt = t(2)
        b.side.pet.xp += 1 // a real change, so B uploads
        _ = b.sync(&cloud, at: t(3))
        _ = a.sync(&cloud, at: t(4))
        #expect(a.side.pet.happiness == 90)
    }

    @Test func filesRoundTripAndConflictCopiesAreHandled() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("standuppal-sync-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let old = SyncedSettings(updatedAt: t(0), deviceID: "A", epoch: "e", settings: AppSettings(), reminders: [])
        var newerSettings = AppSettings()
        newerSettings.petName = "Newer"
        let newer = SyncedSettings(updatedAt: t(5), deviceID: "B", epoch: "e", settings: newerSettings, reminders: [])
        #expect(SyncFiles.write(old, named: "settings.json", in: folder) == nil)
        #expect(SyncFiles.write(newer, named: "settings 2.json", in: folder) == nil)
        let p1 = DeviceProgress(deviceID: "B", deviceName: "B", updatedAt: t(1), epoch: "e", pet: PetState(xp: 5), stats: [:])
        let p2 = DeviceProgress(deviceID: "B", deviceName: "B", updatedAt: t(2), epoch: "e", pet: PetState(xp: 9), stats: [:])
        #expect(SyncFiles.write(p1, named: "progress-B.json", in: folder) == nil)
        #expect(SyncFiles.write(p2, named: "progress-B 2.json", in: folder) == nil)

        let snapshot = try SyncFiles.read(folder).get()
        #expect(snapshot.settings?.settings.petName == "Newer")
        #expect(snapshot.progress.count == 2)

        var mine = SyncSide(settings: AppSettings(), reminders: [], pet: PetState(), stats: [:], sync: LocalSyncState())
        mine.sync.epoch = "e"
        let plan = SyncEngine.plan(mine, remote: snapshot, deviceName: "A", now: t(10))
        #expect(plan.side.pet.xp == 9, "only the newest copy of a Mac's progress counts")
        #expect(plan.macs == 2)
    }

    @Test func aMissingFolderReadsAsEmpty() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("standuppal-missing-\(UUID().uuidString)")
        #expect(try SyncFiles.read(folder).get() == SyncSnapshot())
    }
}
