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
flutter run            # Run app
flutter test           # Run tests
flutter analyze        # Lint / static analysis
./install_debug.sh     # Debug (app: "Mars Thoughts Debug", pkg: com.catchingclouds.marsthoughts.debug)
./install_release.sh   # Release (app: "Mars Thoughts", pkg: com.catchingclouds.marsthoughts)
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
  list under one key. No backend, no sync.

### Key Classes

| Class | Responsibility |
|---|---|
| `Thought` (`domain/`) | Immutable model: id, text, createdAt, updatedAt, pinnedAt, deletedAt. `preview` = first non-empty line. `isDeleted` = in trash. |
| `LocalStorageService` (`data/`) | SharedPreferences wrapper — JSON list of thoughts + theme flag. |
| `ThoughtReadScreen` (`pages/`) | Read-only view of one thought. Owns no text state; double-tap pops a caret offset so `MainScreen` can take over the editing. |
| `ThoughtsManager` (`logic/`) | Single source of truth (`thoughtsNotifier`, all stored thoughts, newest first). Derives `active` / `pinned` / `trash`. `delete` soft-deletes to trash; `restore` / `purge` / `emptyTrash` manage it. Each persists immediately. |
| `ThemeManager` (`theme/`) | Light/dark, toggled from Settings, follows system by default. |

## Screens & Interactions

`MainScreen` stacks three panels on the **vertical** axis (opens on Write):

```
  Pinned                  pinned thoughts          ← swipe down to pull in
  ─────────────────────────────────────────────────────────────────
  Write (base)            blank editor (tap to type)
  ─────────────────────────────────────────────────────────────────
  All thoughts            search + chronological   ← swipe up to pull in
                          list (newest first)
```

- **Navigation**: no `PageView` — a hand-built fingered reveal driven by one
  `AnimationController` (`-1` = Pinned open, `0` = Write, `1` = All open).
  Dragging **up** on Write pulls All in from below — the direction thoughts
  pile up in — and dragging **down** pulls Pinned in from above; releasing
  snaps open or back by distance/velocity. An open panel closes by pulling
  **past its list's far edge** (`OverscrollNotification`), i.e. the reverse of
  the gesture that opened it — same mechanism as the edit screen's
  pull-down-dismiss. A vertical `PageView` would have fought the lists for the
  same axis, hence the hand-built version.
- The reveal drag stays live **while you type** — the editor merely gets first
  refusal on the vertical axis (`_canRevealFrom`): as long as the draft has
  text left to scroll in the drag's direction it scrolls, and once it is pinned
  against that end the gesture goes to navigation. `_RevealDragRecognizer`
  claims or rejects the drag eagerly on that decision, so the editor's own
  scrollable never silently wins the arena. Gating on focus instead would strand
  you on Write with the keyboard up.
- **Write panel**: a single full-screen `TextField`. The draft **stays put**
  when you move between panels — look something up and come back to your
  half-written thought. It is only filed away as a new thought by the
  **`+` button** (bottom right, fades in once the draft is non-empty) or by
  backgrounding the app. So: within a session the draft survives everything,
  across sessions never — every launch starts blank. See `_commitDraft`.
- **Tap** a thought → `ThoughtReadScreen`, which is **read-only**: the text is
  shown as `SelectableText` (no keyboard) so you can read or select/copy via
  the native selection toolbar. **Pull down** past the top or **swipe left**
  closes it back to the list (besides the system back button).
- **Double-tap** the text (a one-time fading hint advertises this) → the screen
  calls its `onEdit(caret)` callback and *then* pops. The callback runs while
  the read screen is still on screen, so `MainScreen` snaps to Write behind it
  (`_navController.value = 0`, no animation) and the list never flashes past;
  the keyboard is raised only after the pop completes. `MainScreen`
  loads that thought into the **write panel**. There is only one editor in the
  app: an old thought is edited in the same field, with the same reveal
  gestures and the same `+`, as a new one. `_editingId` says which thought the
  editor currently holds (`null` = new draft).
- While a thought is loaded, leaving Write writes it back in place
  (`_saveInPlace`) so the list never shows stale text — but an *emptied* one
  isn't written back until you commit, so passing through the list can't
  silently trash it. Tapping that same thought in the list returns to the
  editor instead of opening a stale read view.
- **Long-press** a thought → toggle pin.
- **Swipe a thought right** → delete (moves to trash, silent); **left** → copy
  its text to the clipboard (haptic tick, no snackbar). Both directions are
  free now that navigation is vertical. The pinned list has no row swipe at all
  (unpin first).
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
- **Settings live at the top of the same axis**: open Pinned by pulling down,
  then keep pulling past the **top** of the pinned list and Settings arrive
  (`_onPinnedScroll` watches both edges — bottom closes the panel, top opens
  Settings). One direction, one continuous motion, no gear icon and no menu.
  A one-time hint next to the `PINNED` label advertises it the first time
  Pinned opens (`getSettingsHintSeen`). Long-pressing empty list space still
  works as a silent fallback. Settings leave the way they came: **swipe up**
  and they lift off, back to Pinned (besides the system back button).
- No page-indicator dots — the panels are their own orientation.
- The panels paint **edge to edge** (`SafeArea(bottom: false)`); the lists and
  the settings strip carry the navigation-bar inset themselves. Otherwise the
  panel underneath shows through the translucent system nav bar mid-reveal.
- **Theme**: light/dark is toggled in Settings → Appearance (no gesture).
- A black native splash with the centered logo shows on launch
  (`flutter_native_splash`, `assets/splash_logo.png`).

## Deliberately Out of Scope (v1)

No AI, no voice input, no Markdown, no folders, no tags, no images, no titles,
no checklists, no sync, no templates. A private build may later add voice/AI
transcription behind a flag — never in the public app (API-cost reasons).

## Design Conventions

- Pure black/white + `COLOR_SECONDARY` gray; Outfit font, light weights.
- Constants in `SCREAMING_CASE` in `lib/theme/theme_constants.dart`.
- No cards, borders, shadows, or Material ripple.

## Build Variants

| Variant | Package Name | App Name |
|---------|-------------|----------|
| Debug | `com.catchingclouds.marsthoughts.debug` | Mars Thoughts Debug |
| Release | `com.catchingclouds.marsthoughts` | Mars Thoughts |

Both can be installed simultaneously on the same device.
