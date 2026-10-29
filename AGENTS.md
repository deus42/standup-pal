# StandUp Pal: agent notes

Personal project: a native macOS menu bar stand-up reminder with a fitness pet. This file holds project specifics for coding agents.

## Commands

- Build: `swift build`
- Test: `scripts/test.sh` (wraps `swift test` and points at the Swift Testing macro plugin when only Command Line Tools exist)
- App bundle: `scripts/build-app.sh` (add `--install` to copy to `~/Applications` and launch)
- Visual check without screen-recording permission: `"build/StandUp Pal.app/Contents/MacOS/StandUpPal" --snapshot <dir> [--all-languages]` writes PNGs of every window. Snapshot runs keep state in the separate `com.deus.standuppal.snapshot` defaults suite, skip the single-instance check and mute sounds, so they can run next to the installed app without touching the user's progress.
- Pet art check: `.build/debug/StandUpPal --export-gallery <png>` renders every species, Booty's back view, all gear and dark palettes.

## Rules of the codebase

- Toolchain is Command Line Tools only (no Xcode). Don't write `@State`: use `@ViewState` (see `UI/Components.swift`). Avoid other SwiftUI/Observation macros unless verified to build here.
- Swift 5 language mode, macOS 14 deployment target. App state is `AppStore` (persisted Codable structs, decoded with per-field fallbacks: add new fields to the `init(from:)` extensions).
- Scheduling is derived from the clock each tick (`Scheduler.tick`); keep it idempotent: fired occurrence IDs live in `RuntimeState.firedIDs`.
- No network, no analytics, no bundled assets: pet, icon and sounds are drawn or synthesized in code.
- Three UI languages. Every user-facing string goes through `tr(en, uk, ru)` (or `Words`/`Plural` for counts). Ukrainian and Russian lines must avoid gendered past-tense verbs and adjectives (pet and user gender are unknown). Text saved with user data (default reminder titles) uses `Phrase` so `relocalized()` can follow a language switch.
- Root views carry `.id(store.settings.language)` because some subviews derive text from the global language rather than their inputs; keep that when adding new windows.
- Settings tabs must fit without scrolling: no `Form`/`ScrollView`/`List`; use `SettingsGroup`/`SettingsRow` and cap growing lists (reminders 8, times 6, custom exercises 6). The window sizes itself from the `HeightKey` preference.

## Task records

Agents keep task checkpoints in `tasks/`, which is git-ignored: local notes, not published.
