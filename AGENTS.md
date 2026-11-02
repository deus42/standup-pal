# StandUp Pal: agent notes

Personal project: a native macOS menu bar stand-up reminder with a fitness pet. This file holds project specifics for coding agents.

## Commands

- Build: `swift build`
- Test: `scripts/test.sh` (wraps `swift test` and points at the Swift Testing macro plugin when only Command Line Tools exist)
- App bundle: `scripts/build-app.sh` (flags: `--install` copies to `/Applications`, or `~/Applications` when not writable, and launches; `--universal` builds arm64 + x86_64; `--zip` / `--dmg` write `build/StandUp-Pal-<version>.zip` / `.dmg` plus a `.sha256` for GitHub releases; the DMG window layout comes from `scripts/dmg-layout.py`, which writes the Finder `.DS_Store` directly, so no Finder scripting or extra tools are needed)
- Signing: `scripts/make-signing-cert.sh` (the user runs it once; it touches the login keychain) creates "StandUp Pal Local Signing". build-app.sh signs with it when present, otherwise ad-hoc. Certificate-based designated requirements keep TCC grants across builds, and `Core/Updater.swift` installs only updates that satisfy the running app's requirement (ad-hoc builds never self-update).
- Updates to the user's Macs: `--publish-update` (implies `--zip`) puts the zip and `latest.json` (`{version, build, file, sha256, date}`) in `iCloud Drive/StandUp Pal/Updates/`, and the DMG in `Installer/` when built with `--dmg`. Bump `CFBundleVersion` every release: the updater compares build numbers.
- Release: `scripts/build-app.sh --universal --dmg --zip`, then `gh release create v<version> build/StandUp-Pal-<version>.{dmg,zip}*`. Builds are ad-hoc signed and not notarized, so release notes must keep the Gatekeeper "Open Anyway" / `xattr` steps.
- Visual check without screen-recording permission: `"build/StandUp Pal.app/Contents/MacOS/StandUpPal" --snapshot <dir> [--all-languages]` writes PNGs of every window. Snapshot runs keep state in the separate `com.deus.standuppal.snapshot` defaults suite, skip the single-instance check and mute sounds, so they can run next to the installed app without touching the user's progress. Add `--showcase` for the README demo state (level 10, gear, two weeks of stats, all-day work hours).
- README art: `--export-lineup docs/lineup.png` (species banner) and `--export-icon` (app icon).
- Pet art check: `.build/debug/StandUpPal --export-gallery <png>` renders every species, Booty's back view, all gear and dark palettes.

## Rules of the codebase

- Toolchain is Command Line Tools only (no Xcode). Don't write `@State`: use `@ViewState` (see `UI/Components.swift`). Avoid other SwiftUI/Observation macros unless verified to build here.
- Swift 5 language mode, macOS 14 deployment target. App state is `AppStore` (persisted Codable structs, decoded with per-field fallbacks: add new fields to the `init(from:)` extensions).
- Scheduling is derived from the clock each tick (`Scheduler.tick`); keep it idempotent: fired occurrence IDs live in `RuntimeState.firedIDs`.
- No network, no analytics, no bundled assets: pet, icon and sounds are drawn or synthesized in code.
- iCloud sync goes through files in `~/Library/Mobile Documents/com~apple~CloudDocs/StandUp Pal/` (iCloud Drive), because CloudKit/KVS need a paid developer account and the builds are ad-hoc signed. `settings.json` (settings + reminders) is last-writer-wins; each Mac writes only `progress-<deviceID>.json` with its own contribution, and totals are sums (`Model/Sync.swift`, `SyncEngine.plan` is pure and tested). Resetting progress bumps `epoch`. Snapshot runs never sync; `STANDUPPAL_SYNC_FOLDER` redirects the folder for testing. Device-local bookkeeping lives in `sync.v1`.
- Three UI languages. Every user-facing string goes through `tr(en, uk, ru)` (or `Words`/`Plural` for counts). Ukrainian and Russian lines must avoid gendered past-tense verbs and adjectives (pet and user gender are unknown). Text saved with user data (default reminder titles) uses `Phrase` so `relocalized()` can follow a language switch.
- Root views carry `.id(store.settings.language)` because some subviews derive text from the global language rather than their inputs; keep that when adding new windows.
- Eye breaks are `ReminderKind.eyeBreak` occurrences (`eyes@<day>T<min>`) that go through the same idempotent tick but never queue: `Scheduler.offerEyeBreak` shows them only when nothing else is on screen. Water and eye-break counters are additive in `DayStats`/`PetState` and must stay in `ProgressMath` for sync. Achievements are derived (`Model/Achievements.swift`); only "seen" state is stored, per Mac.
- The pet's day comes from the clock: `DayRhythm.phase` (morning, work, home, night; work hours win over bedtime) drives `Scheduler.petMood` and `Scheduler.dressedLook`. `PetLook.dressed(for:)` swaps the gym gear for outfits. Use the dressed look where the pet shows "now" (menu bar, popover, reminder card, eye break, desktop pet), and the plain `store.petLook` where gear is shown or celebrated (settings, warm-up, weekly card). Bedtime nudges are not occurrences: `RuntimeState.bedtimeNudgedAt` plus `DayRhythm.bedtimeNudgeDue` keep them idempotent, every 30 min while you're present. Snapshots pin a phase with `Scheduler.phaseOverride`. The bedtime card plays `BedtimeScenePainter` (laptop, walk, bed); `BedPainter` is the shared front-on bed, also used by the desktop pet at night.
- The desktop pet (`UI/DesktopPet.swift`) takes the mouse through `PetMouseView` in screen coordinates: drag, toss with gravity and bounces, double-click flip, stroking, and eyes that follow the cursor (`PetPainter.gaze`). Its timer runs at 60 fps only while it's held or flying. Non-exercise motions (`walk`, `typing`, `closeLid`, `yawn`, `dangle`) live in `ExerciseMotion` and are posed by `PetPainter.everydayPose`.
- There is no water tracking (removed in 1.7); old `water`/`totalWater`/`tracksWater` keys in saved or synced data are simply ignored.
- Settings tabs must fit without scrolling: no `Form`/`ScrollView`/`List`; use `SettingsGroup`/`SettingsRow` and cap growing lists (reminders 8, times 6, custom exercises 6). The window sizes itself from the `HeightKey` preference.

## Task records

Agents keep task checkpoints in `tasks/`, which is git-ignored: local notes, not published.
