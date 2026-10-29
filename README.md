# StandUp Pal 🧍

A native macOS menu bar app with a pet that gets you out of your chair **5 minutes before every working hour ends**, walks you through a short warm-up, and levels up every time you move.

![The pet's moods](docs/pets.png)

## What it does

**Stand-up reminders**
- Fires at **:55 of every working hour** by default (09:55 … 17:55 for a 9–18 day).
- Configurable: working hours, work days, interval (30 min to 2 h), minutes before the slot ends, an optional quiet lunch break.
- The reminder is a floating card in the top-right corner that **never steals keyboard focus**. Its buttons: *Start warm-up*, *Stood up*, *Snooze 5 min* (up to 3 times), *Skip*.
- A gentle second nudge after 3 minutes. The card retires on its own after 20 minutes.

**Guided warm-up**
- 2, 3 or 5 minutes, with a fresh random mix each time: an energising opener, a shuffled middle, then a calm closer (breathing or an eye break).
- 16 built-in exercises. You can switch any of them off or **add your own**.
- Countdown ring, "up next" preview, pause/skip/end, optional spoken exercise names, and confetti at the end.

**Extra reminders (your own exercises)**
- Push-ups, water, a walk, anything: pick an emoji, a note, set times ("11:30 and 16:30") or an interval ("every 2 h from 10:00 to 18:00"), and the days.
- When one pops up: **Done**, **+1 hour**, **+2 hours**, or **Skip**.

**The pet**
- Four species (Blob, Kitty, Bunny, Bear), any colour, seven animated moods. It sleeps outside work hours, waves when it's time, sweats during warm-ups, and sulks a little when you skip.
- Earns XP from stand-ups and warm-ups and levels up, unlocking accessories: 🌱 Sprout (Lv 2), 🎽 Sweatband (Lv 4), 🥳 Party hat (Lv 6), 😎 Shades (Lv 8), 👑 Crown (Lv 10).
- Happiness, daily goal, streaks (days off never break a streak), and a 14-day chart.
- Tap it in the popover. It likes that.
- Don't want a pet? Untick **Pet** and you get a clean SF Symbol and the same reminders.

**Smart behaviour** (each can be switched off)
- **Already away?** If there's been no keyboard or mouse input for 5+ minutes when a stand-up is due, it counts as done and stays quiet.
- **On a call?** If your camera or microphone is in use, reminders wait (silently) until the call ends. This only asks macOS whether a device is busy; it never records anything and needs no permissions.
- Sleep/wake safe: reminders missed while the Mac slept are dropped, not dumped on you all at once.

**Sounds**: soft, synthesized chimes (Soft chime, Marimba, Kalimba, Bubble pop, or the system Tink/Glass), a volume slider, and one **Sound** checkbox to turn them all off.

## Using it

- **Click** the pet in the menu bar to open its home: countdown, today's progress, upcoming extras, and the **Sound** / **Pet** checkboxes.
- **Right-click** it for a quick menu: start a warm-up, toggle Sound/Pet/countdown, pause (30 min, 1 h, 2 h, until tomorrow), Settings, Quit.
- The countdown next to the icon hides overnight and on weekends.

## Build & install

Needs macOS 14+ and Swift (Command Line Tools are enough; no Xcode required).

```bash
scripts/build-app.sh --install
```

This builds a release `.app`, renders its icon, signs it ad-hoc, copies it to `~/Applications` and launches it. Without `--install` the app lands in `build/StandUp Pal.app`.

Turn on **Settings › General › Launch at login** to have it start automatically.

## Development

```bash
swift build                 # debug build
scripts/test.sh             # 21 tests: scheduling, live ticks, flows, persistence, routines
```

Handy launch flags for the built binary:

| Flag | Does |
| --- | --- |
| `--demo-reminder` / `--demo-extra` | show a preview reminder card |
| `--demo-warmup` | start a warm-up |
| `--open-settings` / `--open-popover` | open those windows |
| `--snapshot <dir>` | render every window to PNGs, then quit (no screen-recording permission needed) |
| `--export-icon <png>` / `--export-gallery <png>` | render the app icon / all pets |

Layout:

```
Sources/StandUpPal/
  App/        AppDelegate (status item, menus, windows), entry point, icon export
  Core/       AppStore (persistence), Scheduler, Presence (idle/camera/mic), SoundPlayer (synth), PetTalk
  Model/      Settings, reminders, exercises, progress
  UI/         Popover, reminder card, warm-up, settings tabs, pet painter
```

Notes:
- Everything (pet, icon, sounds) is drawn or synthesized in code, so there are no asset files.
- In the macOS 27 SDK `@State` resolves to a macro whose plugin ships only with full Xcode, so views use `@ViewState` (a typealias to the same property wrapper). `scripts/test.sh` similarly points the compiler at the Swift Testing macro plugin when only Command Line Tools are installed.
- State lives in `UserDefaults` (`com.deus.standuppal`). To start over: `defaults delete com.deus.standuppal`.

Everything stays on your Mac: no accounts, no network, no analytics.
