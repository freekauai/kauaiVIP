# Session handoff — RunSheet (KauaiVIP2026)

_Last updated: 2026-08-30_

Read `CLAUDE.md` at `~/Desktop/vip 2026/CLAUDE.md` first — it has the project
layout, the nested-repo trap, and the hard rules. This file is only the
"where we left off" state.

## Where things stand

**Version 1.5.4, build 3** — committed, tagged, pushed, working tree clean,
**uploaded to App Store Connect as 1.5.4 (3)** (renamed from 1.5.3 in Xcode,
archived from the GUI on 2026-08-30).

| | |
|---|---|
| HEAD | `3849638` "Version 1.5.4 (build 3)" |
| Tag | `v1.5.4-build3` |
| Remote | in sync with `origin/main` (`git@github.com:freekauai/kauaiVIP.git`) |
| Archive | `~/Library/Developer/Xcode/Archives/2026-08-30/` (GUI archive, 1:10 PM) — uploaded; older CLI archives under 2026-08-09 are dead, delete from Organizer |

**Status: UPLOADED as 1.5.4 (3). Remaining: create the 1.5.4 version entry in App Store Connect, attach the build, paste the texts below, submit for review.**

## Why 1.5.3 and not 1.5.2 (2) — IMPORTANT

The 1.5.2 (2) upload was **rejected by App Store Connect** (errors 90062 +
90186): 1.5.2 was already approved at some point, and an approved version
"train" is closed forever — a higher build number alone is never enough, the
`MARKETING_VERSION` itself must go up. So the paste-import feature ships as
**1.5.3** together with this session's fixes. The dead
`RunSheet 1.5.2 (2).xcarchive` may still sit in Organizer — ignore/delete it.
(This rule is now also noted in CLAUDE.md.)

## What's in 1.5.4 (3)

Everything from 1.5.2 build 2 (editable Paste Trips preview + clipboard-race
fix, see commit `2f90325`) **plus** two polish rounds (`b766c9f`, `e6a93dd`, `a2c4d55`), the full Places suite (note detection → card tags → By Place stats → route builder → Settings editor with rename/drag-reorder and Airport/Hotel/House/Business defaults), and the staged splash animation with engine sound (`.ambient`, respects silent switch) — CSV/PDF fixes and a full simulator-verified UI polish pass (safe-area CTAs, compact Add Trip form, weather tile, autocorrect off on names, leaner home screen). Highlights of `b766c9f`:

- CSV export: vehicle/service names quoted; newlines in notes flattened to
  `" / "` — custom names with commas and multi-line notes now survive
  export → re-import (the importer splits on `\n` before parsing quotes).
- PDF exports (both renderers): row height accounts for wrapped
  vehicle/service names, so long custom names can't overlap the next row.
- CSV import: overlap warning card (same as NewPeriodView's).
- Monthly CSV export: trips sorted by date within each month.
- Theme change no longer teleports to period detail (`didAutoNavigate` is a
  per-launch `static`, surviving the `.id(appTheme)` tree rebuild).
- Trip-delete alert no longer claims "cannot be undone" (Undo toast exists).
- Comment/doc drift fixed: charter-hours comments, iOS 17 min-deployment
  header, CLAUDE.md rules 3 & 4.

## Code + math review (this session): clean

Full review of all 22 Swift files (~8,000 lines). No crash patterns, every
`.sheet` correctly re-injects environment objects (`SurfSpotsMapView` and
`FAQView` are self-contained — safe bare). All calculations were verified by
**executing** the formulas: 49/49 assertions passed covering charter billing
(+1h allowance, overnight roll, strict <16h guard, PU==DO minimum), duty
span, trip-date anchoring, dispatch-parser times (930am/12am/12pm/1230pm),
CSV quote round-trip, moon-phase epoch (checked against real Aug 2026 new/full
moons), compass rounding, gauge clamping, weekday tally, and the 12h↔24h
time wheel. The harness lived in the session scratchpad (temp) — regenerate
on request; the logic was copied verbatim so it's cheap to rebuild.

Known non-issues, on record:

- `dayCount` would undercount by 1 if a period's end date carried an earlier
  clock time than its start — **unreachable today** (NewPeriodView keeps
  times aligned; CSV import normalizes to startOfDay). Matters only if a
  period-editing UI is ever added; fix would be startOfDay at creation.
- The CSV importer still can't read *foreign* CSVs with embedded newlines
  inside quoted fields; our own exports no longer produce them.

## Next steps

1. ~~Archive + upload~~ — done, build 1.5.4 (3) is in App Store Connect.
2. In App Store Connect, create the **1.5.4** version entry, attach build 3.
3. Paste the texts below, submit for review.

### "What's New" (release notes field, 4,000-char limit)

```
Paste Trips just got smarter - and RunSheet now knows your places.

- Paste dispatch texts and correct every run right in the preview: date, pickup time, client name, service, vehicle, and notes.
- New: Places. RunSheet spots Airport, Hotel, House, Business (and places you add) in trip notes, tags them on trip cards, and breaks them down in Stats.
- New: route builder. Tap places to build "Hotel to Airport" routes in your notes without typing.
- Make Places yours: add, rename, and drag to reorder them in Settings.
- Fresh look: a new animated splash (with a little engine rumble), cleaner CSV exports, better PDF layouts, and polish throughout.

Made on Kauai with Aloha.
```

### Promotional text (170-char limit, version-independent)

```
Stop retyping dispatch texts. Paste them in and RunSheet fills in dates, times, names, and vehicles — edit anything before it's added. Built for Kauai drivers.
```

159 characters. If App Store Connect mangles the em dash or apostrophe on
paste, retype them as plain ASCII.

## Disk space

Improved since last session: **35 GB free of 228 GB (83% full)** — plenty for
builds. If it drifts back down and a build dies with
`database or disk is full`, the fix is still:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/vip_2026-*
```

Check with `df -h /System/Volumes/Data`. Known large and NOT safe to delete:
`/Library/Developer/CoreSimulator` (iOS runtime, in use).

## Reminders that bit us before

- Only edit files under `KauaiVIP2026/vip 2026/vip 2026/`. Every other
  `.swift` in the tree is a stale April copy.
- Run git from `KauaiVIP2026/vip 2026/`. From higher up, git resolves to the
  unrelated Kauai Today repo rooted at `~`.
- Every `.sheet { }` must re-inject `.environmentObject(store)` — sheets don't
  inherit it, and the failure is a runtime crash with no compile error.
- Don't de-localize. The approved App Store build is the full Kauai format.
- An approved App Store version closes its train — always bump
  `MARKETING_VERSION` for a new submission, never just the build number.
