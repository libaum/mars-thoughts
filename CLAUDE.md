# CLAUDE.md

Mars Thoughts — capture a thought before it disappears. Its single job: **get a
thought out of your head and saved with the least possible friction.** Not
notes, not a wiki. Opens straight into a blank editor; there is no save button
anywhere.

Shared Mars conventions: `../DESIGN.md`, `../PHILOSOPHY.md`. Reference app:
`../mars_fx`. This file only adds what is specific to this app or not obvious
from the code.

## Commands

```bash
flutter run --flavor store   # a --flavor is mandatory (see Build Variants)
flutter test
flutter analyze
./install_debug.sh           # store debug; FLAVOR=personal for the sync build
./install_release.sh         # store release
./install_personal.sh        # personal release
```

Release, from `android/`: `bundle exec fastlane alpha | production | metadata`
(`*_upload` variants push an already-built AAB). Needs
`android/fastlane/pc-api.json` and `android/key.properties` — git-ignored,
never commit them. Store copy: `android/fastlane/metadata/android/`.

## Build Variants

Flavors `store` / `personal` × debug / release; all four install side by side.

| Variant | Package | INTERNET |
|---|---|---|
| storeRelease | `com.catchingclouds.marsthoughts` | **no** |
| storeDebug | `….marsthoughts.debug` | tooling only |
| personalRelease | `….marsthoughts.personal` | yes |
| personalDebug | `….marsthoughts.personal.debug` | yes |

Only `store` ever goes to the Play Store. The applicationId is fixed (also in
`android/fastlane/Appfile`); changing it makes a new app identity, so ask first.

## Hard rules

- **Sync is personal-flavor only.** Gate: `kSyncEnabled` (`lib/sync/sync_flags.dart`),
  a compile-time constant from `appFlavor`. Never gate on a runtime value — the
  store release must contain no sync code at all (verified via the AOT snapshot).
  Read `../mars_sync_relay/SECURITY.md` before touching anything sync-related.
- **Desktop boundary.** `domain/`, `logic/`, `data/`, `sync/`, `util/` are
  imported by `../mars_hub` (Linux, no flavor). They must not read
  `kSyncEnabled` or use Android-only plugins — `test/desktop_boundary_test.dart`
  enforces it. Gate only in `services/`, `pages/`, `main.dart`.
- **Showcase data** (`ShowcaseDataSource`) overwrites stored thoughts in every
  store *debug* build (for Play Store screenshots). It must never run in the
  personal flavor — the fake thoughts would sync to the relay.
- **Local storage is the source of truth**; the relay only holds an encrypted
  copy. Sync keys live in `flutter_secure_storage`, never SharedPreferences.
- Sync never throws into the UI flow; errors land in `SyncStatus`.

## Data & sync model

- `Thought` has two clocks: `updatedAt` = last *text* edit (drives list order),
  `changedAt` = last change of any kind (pin, trash, restore) = the sync clock.
- Delete is soft (trash); only a *purge* becomes a sync tombstone.
- Last-write-wins by `changedAt`, tie-break by device id. Remote edits are
  applied via `applySynced` *without* restamping.
- **Editor baseline:** an open but untouched thought must never overwrite an
  edit that synced in from another device — write-back is a no-op while the
  editor still equals the text it was loaded with; an untouched editor follows
  remote edits instead.
- Known limit: a thought purged elsewhere while you're actively typing in it
  loses the unsaved text when you leave Write.

## Interaction — the decisions behind it

- **One vertical axis**, top to bottom: Settings · Pinned · **Write** (home) ·
  All. Pull down for Pinned, keep pulling for Settings; pull up for All. No gear
  icon, no menu, no read screen — one editor for new and old thoughts.
- The filmstrip is hand-built, not a `PageView`: a vertical `PageView` fights
  the lists for the same axis. The `ListView`s always win a gesture race, so
  they hand overscroll to the shared drag logic instead of competing.
- The reveal stays live while typing; the editor gets first refusal only while
  it still has text to scroll in that direction. Gating on focus would strand
  you on Write with the keyboard up.
- **Never pop the keyboard on its own** — not on launch, not when opening a
  thought. It felt pushy.
- The draft stays put across panels and is filed only by the `+` button — or
  when the app goes to background (then the editor reopens blank after a cold
  start; the thought is in the list). Leaving Write writes a loaded thought back
  in place, except an emptied one, so passing through the list can't trash it.
- Row swipe: left = trash, right = copy. Fires only at the full stop (haptic
  tick there), so a hesitant thumb does nothing. No undo snackbar; trash is the
  undo. No row swipe on Pinned.
- Panels paint edge to edge; lists carry the nav-bar inset themselves, or the
  panel underneath shows through the translucent nav bar mid-reveal.

## Deviations from the Mars standard

- Theme defaults to **dark** on a fresh install, not the system theme.
- Light/dark background colour is user-adjustable in Settings (presets + picker).

## Out of scope

No AI, voice, Markdown, folders, tags, images, titles, checklists, templates.
Sync, and possibly voice/AI later, only ever in the `personal` flavor.
