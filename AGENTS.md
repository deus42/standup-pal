# StandUp Pal: agent notes

Personal project: a native macOS menu bar stand-up reminder with a fitness pet. This file holds project specifics for coding agents.

## Commands

- Build: `swift build`
- Test: `scripts/test.sh` (wraps `swift test` and points at the Swift Testing macro plugin when only Command Line Tools exist)
- App bundle: `scripts/build-app.sh` (add `--install` to copy to `~/Applications` and launch)
- Visual check without screen-recording permission: `"build/StandUp Pal.app/Contents/MacOS/StandUpPal" --snapshot <dir>` writes PNGs of every window. It runs a real warm-up, so it adds XP and stats; run `defaults delete com.deus.standuppal` afterwards for a clean state.

## Rules of the codebase

- Toolchain is Command Line Tools only (no Xcode). Don't write `@State`: use `@ViewState` (see `UI/Components.swift`). Avoid other SwiftUI/Observation macros unless verified to build here.
- Swift 5 language mode, macOS 14 deployment target. App state is `AppStore` (persisted Codable structs, decoded with per-field fallbacks: add new fields to the `init(from:)` extensions).
- Scheduling is derived from the clock each tick (`Scheduler.tick`); keep it idempotent: fired occurrence IDs live in `RuntimeState.firedIDs`.
- No network, no analytics, no bundled assets: pet, icon and sounds are drawn or synthesized in code.

## Task records

Agents keep task checkpoints in `tasks/`, which is git-ignored: local notes, not published.
