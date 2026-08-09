# Session handoff — RunSheet (KauaiVIP2026)

_Last updated: 2026-08-09_

Read `CLAUDE.md` at `~/Desktop/vip 2026/CLAUDE.md` first — it has the project
layout, the nested-repo trap, and the hard rules. This file is only the
"where we left off" state.

## Where things stand

**Version 1.5.2, build 2** — committed, tagged, pushed, working tree clean.

| | |
|---|---|
| HEAD | `c91dcf4` "Version 1.5.2 (build 2)" |
| Tag | `v1.5.2-build2` |
| Remote | in sync with `origin/main` (`git@github.com:freekauai/kauaiVIP.git`) |
| Build | Release configuration builds clean, no errors |

**Status: ready to archive and submit. Nothing is half-finished.**

## What shipped in build 2

Editable Paste Trips preview (`vip 2026/PasteImportView.swift`, commit `2f90325`):

- Every parsed run can be corrected **before** it's added — date and pickup
  time via native compact pickers, client name and notes as text fields,
  service and vehicle as tap-to-change menus.
- Include/exclude moved onto the checkmark button only, so tapping a text
  field can no longer toggle a run off by accident.
- Runs parsed without a time get a "+ Time" button that seeds 9:00 AM.
- "Paste from Clipboard" falls back to async item-provider loading when the
  synchronous pasteboard string is nil — this is the race right after iOS's
  paste-permission prompt, which used to make the first tap silently do nothing.

Verified live in the simulator: a real dispatch text parsed correctly,
including a minutes-less "9 am" → 9:00 AM, and duplicate detection excluded
only the runs already in the period.

## Next step: archive in Xcode

1. Open `vip 2026.xcodeproj`.
2. Set destination to **Any iOS Device (arm64)** — Archive is greyed out on a
   simulator destination.
3. **Product → Archive**, then validate and upload from the Organizer.
   It appears as **1.5.2 (2)**.

## App Store promotional text (170-char limit, no build needed to change)

Recommended:

```
Stop retyping dispatch texts. Paste them in and RunSheet fills in dates, times, names, and vehicles — edit anything before it's added. Built for Kauai drivers.
```

159 characters. If App Store Connect mangles the em dash or apostrophe on
paste, retype them as plain ASCII.

"What's New" release notes were **not** written yet — ask for them if needed
(separate field, 4,000-char limit; would cover the editable paste preview
and the clipboard fix).

## Disk space — recurring problem, read before building

The Mac's data volume runs near full. Mid-build exhaustion **corrupts Xcode's
build database** and produces:

```
error: accessing build database "…/XCBuildData/build.db": database or disk is full
```

Fix — delete the project's DerivedData, which regenerates cleanly:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/vip_2026-*
```

Current free space: **14 GB of 228 GB (94% full)**. That is enough to archive,
but it drifts down. Check before a long build:

```bash
df -h /System/Volumes/Data
```

Space already reclaimed this session (don't re-hunt these):

- `~/Library/Developer/Xcode/iOS DeviceSupport/*` — was 13 GB, cleared. It
  refills as devices connect; safe to clear again.
- `xcrun simctl delete unavailable` — removed dead simulators.

Known large and **not** safe to delete: `/Library/Developer/CoreSimulator`
(19 GB, the iOS 26.5 runtime — only one installed, it's in use) and
`~/Library/Developer` (11 GB). Roughly 100 GB of the volume is unaccounted
for by `du`, typically purgeable system data. `Downloads` (3.5 GB) is the
easy win if more headroom is wanted — user's call, don't delete unasked.

## Reminders that bit us before

- Only edit files under `KauaiVIP2026/vip 2026/vip 2026/`. Every other
  `.swift` in the tree is a stale April copy.
- Run git from `KauaiVIP2026/vip 2026/`. From higher up, git resolves to the
  unrelated Kauai Today repo rooted at `~`.
- Every `.sheet { }` must re-inject `.environmentObject(store)` — sheets don't
  inherit it, and the failure is a runtime crash with no compile error.
- Don't de-localize. The approved App Store build is the full Kauai format.
