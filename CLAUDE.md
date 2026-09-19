# CLAUDE.md

This file provides guidance when working with code in this repository.

## Project Overview

Mars Thoughts is a minimal Flutter Android app for capturing fleeting thoughts.
Its single job: **get a thought out of your head and saved with the least
possible friction.** Not notes, not a wiki, not knowledge management — thoughts
that you want to hold onto before they disappear. Part of the Mars product family.

The app opens straight into a blank editor. Tap it, you type, you leave, it's
saved. There is no save button anywhere. The keyboard is never raised on its
own — auto-popping it felt pushy, so capture starts the moment you tap.

## Common Commands

```bash
flutter run --flavor store   # Run app (a --flavor is mandatory now, see Build Variants)
flutter test                 # Run tests
flutter analyze              # Lint / static analysis
./install_debug.sh           # Store debug ("Mars Thoughts Debug"); FLAVOR=personal for the sync build
./install_release.sh         # Store release ("Mars Thoughts", pkg: com.catchingclouds.marsthoughts)
./install_personal.sh        # Personal release ("Mars Thoughts Personal", pkg: …marsthoughts.personal)
```

### Release (fastlane, from `android/`)

```bash
bundle install                    # once, installs fastlane into vendor/bundle
bundle exec fastlane alpha        # build release AAB + upload to Play closed testing (draft)
bundle exec fastlane production   # build release AAB + upload to production
bundle exec fastlane metadata     # update store listing only
bundle exec fastlane alpha_upload      # upload an already-built AAB to alpha (no rebuild)
bundle exec fastlane production_upload # upload an already-built AAB to production (no rebuild)
```

Needs `android/fastlane/pc-api.json` (Play service-account key) and a release
keystore via `android/key.properties` — both git-ignored, never committed.
Store copy lives in `android/fastlane/metadata/android/en-US/`.

## Architecture

Follows the shared Mars conventions (see ../DESIGN.md). Reference app: ../mars_fx.

- **DI**: `GetIt` singletons in `lib/services/service_locator.dart`, set up in
  `main()` before `runApp`. `LocalStorageService` (async) is registered first.
- **State**: `ValueNotifier` + `ValueListenableBuilder`. No Bloc/Provider/Riverpod.
- **Persistence**: SharedPreferences only, local. Thoughts are stored as a JSON
  list under one key. The store flavor has no backend and no sync — the
  personal flavor layers an opt-in sync on top (see Sync below) without
  changing that: local storage stays the source of truth.

### Key Classes

| Class | Responsibility |
|---|---|
| `Thought` (`domain/`) | Immutable model: id, text, createdAt, updatedAt, changedAt, pinnedAt, deletedAt. `preview` = first non-empty line. `isDeleted` = in trash. `updatedAt` = last *text* edit (drives list order); `changedAt` = last change of *any* kind (pin, trash, restore too) — the sync clock. Legacy JSON without `changedAt` falls back to `updatedAt`. |
| `LocalStorageService` (`data/`) | SharedPreferences wrapper — JSON list of thoughts, theme flag, draft, and one-time hint/tutorial flags, plus the `Animations` toggle (`getAnimationsEnabled`/`setAnimationsEnabled`). The `sync_*` keys at the bottom (purged ids, hub URL, last-sync watermark) are only read by the personal flavor. |
| `ThoughtsManager` (`logic/`) | Single source of truth (`thoughtsNotifier`, all stored thoughts, newest first). Derives `active` / `pinned` / `trash`. `delete` soft-deletes to trash; `restore` / `purge` / `emptyTrash` manage it. `togglePinMany`/`deleteMany` do the same in one batch commit for multi-select. Each persists immediately and stamps `changedAt`. `applySynced` writes remote edits *without* restamping. Purges are remembered for sync when `recordPurges` (defaults to the flavor flag). |
| `ThemeManager` (`theme/`) | Light/dark, toggled from Settings. No preference yet defaults to dark (not system) — see `ThemeManager()`. |
| `ShowcaseDataSource` (`data/`) | Curated example thoughts that seed the app for Play Store screenshots. Gated by `enabled` (`kDebugMode && !kSyncEnabled`), wired in `service_locator.dart` — every *store* debug build starts with this data, overwriting whatever was stored. Never in the personal flavor, or the fake thoughts would sync to the hub. |
| `SyncService` (`sync/`) | Personal flavor only. Pairing state (hub URL + device token + encryption key), builds the `MarsSyncEngine`, and `syncNow()` (overlapping calls collapse into one). Status via `statusNotifier`. |
| `ThoughtsSyncRepository` (`sync/`) | Personal flavor only. Maps thoughts onto `mars_sync`'s generic items: whole `Thought` as payload, ordered by `changedAt`; a *purge* becomes a tombstone, trashing is just an edit. |
| `SecureSyncKeyStore` (`sync/`) | Personal flavor only. Device token, encryption key and device id in Keystore-backed `flutter_secure_storage`, never SharedPreferences. |

### Sync (personal flavor only)

Built on the shared `../mars_sync` package (client) and `../mars_sync_hub`
(server) — read `../mars_sync_hub/SECURITY.md` before touching anything here.

- Gate: `kSyncEnabled` in `lib/sync/sync_flags.dart` is `appFlavor == 'personal'`,
  a compile-time constant. In the store flavor every `if (kSyncEnabled)` branch
  is dead code and tree-shaken out — verified: the store release's AOT snapshot
  contains no sync strings at all. Never gate on a runtime value instead.
- Local storage stays the source of truth; the hub is a relay. Bidirectional,
  last-write-wins by `changedAt`, deterministic tie-break by device id.
- Payloads are AES-256-GCM encrypted on device before they leave; the hub only
  ever sees ciphertext. One key for all your devices, generated once, moved
  between devices by hand (Settings → Sync → Show/Paste) — never via the hub.
  **Losing the key makes everything on the hub unreadable; back it up.**
- Triggers: cold launch (post-frame), `resumed`, and `paused` (after the draft
  is filed, so it travels too), plus "Sync now" in Settings → Sync. All
  best-effort; errors land in `SyncStatus`, never in the UI flow.
- Known limit: if a thought is purged on another device while it's loaded in
  the editor here, leaving Write drops the edit (`update` finds no id).

## Screens & Interactions

`MainScreen` stacks four panels on one continuous **vertical** axis, top to
bottom, opening on Write:

```
  Settings                 appearance, animations,  ← keep pulling down past
                            trash, about               Pinned's top edge
  ─────────────────────────────────────────────────────────────────
  Pinned                   pinned thoughts          ← swipe down to pull in
  ─────────────────────────────────────────────────────────────────
  Write (base)              blank editor (tap to type)
  ─────────────────────────────────────────────────────────────────
  All thoughts              search + chronological   ← swipe up to pull in
                            list (newest first)
```

- **Navigation**: no `PageView` — a hand-built fingered reveal driven by one
  `AnimationController` (`_navController`, one continuous filmstrip: `-2` =
  Settings, `-1` = Pinned, `0` = Write, `1` = All). Every panel is positioned
  by the same formula (`_positioned`: `(slot - value) * height`), so the whole
  stack always moves together, never just the incoming panel sliding over a
  static one. Dragging **up** on Write pulls All in from below — the direction
  thoughts pile up in — dragging **down** pulls Pinned in from above, then
  keeps going into Settings if you keep pulling past the top of the pinned
  list. A vertical `PageView` would have fought the lists for the same axis,
  hence the hand-built version.
- Write and Settings are driven by a competing raw drag recognizer
  (`_RevealDragRecognizer`, a `VerticalDragGestureRecognizer` that claims or
  rejects the gesture eagerly once the finger clearly commits to the vertical
  axis) feeding the shared `_onDragStart`/`_onDragUpdate`/`_onPanelDragEnd`.
  Pinned and All are plain `ListView`s — a `ListView`'s own scroll recognizer
  reliably wins that race once it has real content, so a competing recognizer
  doesn't work there. Instead they listen to their own `ScrollNotification`s
  and, once pulled into overscroll past their own edge, feed the *same* shared
  `_onDragStart`/`_onDragUpdate`/`_onPanelDragEnd` via the notifications' raw
  `dragDetails` (`_onPinnedScroll`/`_onAllScroll`) — so all four panels end up
  driven by identical drag/fling logic, just fed from two different gesture
  sources.
- Releasing a drag snaps to whichever neighbour it committed to — by fling
  velocity (`_flingVelocity`) or by distance past `_openThreshold` — or springs
  back home otherwise (`_onPanelDragEnd`). With the **Animations** toggle in
  Settings on (the current default), the whole stack visibly follows the
  finger while dragging (`_animateDrag`); off it stays put until the gesture
  resolves, then cuts straight to the result.
- The reveal drag on Write stays live **while you type** — the editor merely
  gets first refusal on the vertical axis (`_canRevealFrom`): as long as the
  draft has text left to scroll in the drag's direction it scrolls, and once
  it's pinned against that end the gesture goes to navigation. Gating on focus
  instead would strand you on Write with the keyboard up.
- **Write panel**: a single full-screen `TextField`. The draft **stays put**
  when you move between panels — look something up and come back to your
  half-written thought. Within the app it is only filed away as a new thought
  by the **`+` button** (bottom right, fades in once the draft is non-empty),
  never just by switching panels — it's debounce-persisted to
  `LocalStorageService` as you type (`_scheduleDraftSave`) so a background OS
  kill mid-session can't lose it. See `_commitDraft`.
  Backgrounding the app itself (`didChangeAppLifecycleState`,
  `_fileDraftOnBackground`) is treated differently from an internal panel
  switch: a non-empty draft is filed away right then (mirroring `+`) and the
  persisted draft entry cleared. If the process survives in the background
  and simply resumes, this is invisible — the in-memory editor and
  `_editingId` are untouched, so it looks unchanged, just now backed by a real
  thought. But if the process is actually killed while backgrounded, a cold
  relaunch finds no draft and opens **blank** — the thought itself is safe in
  the list, just no longer sitting in the editor.
- **Tap** a thought → loads it straight into the write panel and reveals Write
  (`_openThought` → `_editInWritePanel` + `_animateNavTo`). There is no
  separate read screen: the keyboard is deliberately left alone, so opening a
  thought stays calm rather than pushy — it only appears once you tap into the
  field yourself. There is only one editor in the app: an old thought is
  edited in the same field, with the same reveal gestures and the same `+`, as
  a new one. `_editingId` says which thought the editor currently holds
  (`null` = new draft). Tapping the thought that's already loaded just reveals
  Write and focuses the field (`_returnToWrite`), instead of reloading
  possibly-stale text.
- While a thought is loaded, leaving Write writes it back in place
  (`_saveInPlace`) so the list never shows stale text — but an *emptied* one
  isn't written back until you commit, so passing through the list can't
  silently trash it.
- **Long-press** a thought → enters multi-select mode (`_selectionModeOn`,
  `_selectedIds`). While active, tap toggles a row's selection instead of
  opening it, and a bottom action bar (Cancel / Pin / Copy / Delete) appears.
  Deselecting the last item does *not* auto-exit — only Cancel, running one of
  the three actions, or switching panels does (`_cancelSelection`, called from
  every nav transition). Pin/Delete use `ThoughtsManager.togglePinMany`/
  `deleteMany`; Copy joins the selected texts and writes them to the clipboard
  directly.
- **Swipe a thought left** → delete (moves to trash, silent); **right** →
  copy its text to the clipboard (haptic tick, no snackbar). Both directions
  are free now that navigation is vertical. Suppressed entirely in selection
  mode and on the pinned list (no row swipe there — unpin via the selection
  bar instead). Row swipes use their own axis-disambiguating recognizer
  (`_RowSwipeDragRecognizer`, mirroring `_RevealDragRecognizer`) so a mostly-
  vertical scroll never makes a row jitter sideways.
- Swipe visuals: the row is a tile in the background colour that travels at
  most **a third of its width**; the strip it vacates is filled by an inverted
  tile (`colorScheme.primary`) with the action's icon in the background colour.
  The icon sits centred in that strip at full size and is simply **clipped** by
  its edges early in the swipe (`ClipRect` + `OverflowBox`) — it never scales.
  The action fires **only when the row is pulled all the way to the stop**;
  reaching it ticks once (`HapticFeedback.mediumImpact`) so you can feel the
  action is loaded. Anything short of the stop is a no-op, so nothing is
  deleted by a hesitant thumb.
- Deleting is non-destructive: thoughts go to **Trash** (Settings → Trash),
  where they can be restored or permanently removed. No undo snackbar.
- **Search** (All panel): rows show the matching line(s) with the query
  highlighted (`util/highlight.dart`).
- **Settings** live at the top of the same axis: open Pinned by pulling down,
  then keep pulling past the **top** of the pinned list and Settings arrive.
  One direction, one continuous motion, no gear icon and no menu. A one-time
  hint next to the `PINNED` label advertises it the first time Pinned opens
  (`getSettingsHintSeen`). Long-pressing empty list space still works as a
  silent fallback. Settings leave the way they came: **swipe up** and they
  lift off, back to Pinned (besides the system back button).
- System **back** mirrors swipe-back at whatever level you're at: cancels an
  active selection first, then steps one level back through the stack —
  Settings to Pinned, Pinned/All to Write (`_stepBack`) — before falling
  through to leaving the app.
- No page-indicator dots — the panels are their own orientation.
- The panels paint **edge to edge** (`SafeArea(bottom: false)`); the lists and
  the settings strip carry the navigation-bar inset themselves. Otherwise the
  panel underneath shows through the translucent system nav bar mid-reveal.
- **Theme**: light/dark is toggled in Settings → Appearance. A fresh install
  with no saved preference defaults to **dark**, not the system theme.
- A black native splash with the centered logo shows on launch
  (`flutter_native_splash`, `assets/splash_logo.png`).

## Deliberately Out of Scope (v1)

No AI, no voice input, no Markdown, no folders, no tags, no images, no titles,
no checklists, no templates. No sync **in the public app** — the `personal`
flavor has it (see Sync above), the `store` flavor never will. A private build
may likewise later add voice/AI transcription behind the same flavor — never
in the public app (API-cost reasons).

## Design Conventions

- Pure black/white + `COLOR_SECONDARY` gray; Outfit font, light weights.
- Constants in `SCREAMING_CASE` in `lib/theme/theme_constants.dart`.
- No cards, borders, shadows, or Material ripple.

## Build Variants

Two product flavors (`store`, `personal`) × two build types (debug, release).
Gradle requires `--flavor` on every build now; the scripts and the Fastfile
pass it for you.

| Variant | Package Name | App Name | INTERNET |
|---------|-------------|----------|----------|
| storeDebug | `com.catchingclouds.marsthoughts.debug` | Mars Thoughts Debug | yes (Flutter tooling only) |
| storeRelease | `com.catchingclouds.marsthoughts` | Mars Thoughts | **no** |
| personalDebug | `com.catchingclouds.marsthoughts.personal.debug` | Mars Thoughts Personal Debug | yes |
| personalRelease | `com.catchingclouds.marsthoughts.personal` | Mars Thoughts Personal | yes |

All four can be installed simultaneously on the same device. The label is
assembled per variant in `android/app/build.gradle.kts` (`appLabel`
placeholder); the INTERNET permission comes from
`android/app/src/personal/AndroidManifest.xml` (and the debug/profile ones
for tooling). Only `store` ever goes to the Play Store (`fastlane` builds
`--flavor store`).
