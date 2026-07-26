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
| `ThoughtsManager` (`logic/`) | Single source of truth (`thoughtsNotifier`, all stored thoughts, newest first). Derives `active` / `pinned` / `trash`. `delete` soft-deletes to trash; `restore` / `purge` / `emptyTrash` manage it. Each persists immediately. |
| `ThemeManager` (`theme/`) | Light/dark, toggled from Settings, follows system by default. |

## Screens & Interactions

`MainScreen` is a 3-page `PageView` (opens on the center Write page):

```
  ← All thoughts          Write (center)         Pinned →
  search + chronological   blank editor           pinned thoughts
  list (newest first)      (tap to type)
```

- **Write panel**: a single full-screen `TextField`. Leaving the page or
  backgrounding the app commits the draft as a new thought (if non-empty) and
  clears the editor, so it's always blank on return. See `_commitDraft`.
- **Tap** a thought → `ThoughtEditScreen`, which opens in **read mode**: the
  text is shown as `SelectableText` (no keyboard) so you can read or
  select/copy via the native selection toolbar. **Double-tap** the text to
  edit (a one-time fading hint advertises this); **pull/swipe down** past the
  top closes it back to the list (besides the system back button). Auto-saves
  on pop / app pause; emptying the text moves the thought to the trash.
- **Long-press** a thought → toggle pin.
- **Swipe right** a thought → delete (moves to trash, silent). Swipe is
  **right-only** so a left swipe stays free to page back to Write. The pinned
  list has no swipe-to-delete (unpin first).
- Deleting is non-destructive: thoughts go to **Trash** (Settings → Trash),
  where they can be restored or permanently removed. No undo snackbar.
- **Search** (All panel): rows show the matching line(s) with the query
  highlighted (`util/highlight.dart`).
- **Long-press the page-indicator dots** (bottom, every panel incl. Write) →
  Settings. Long-pressing an empty list area also works. No gear icon.
- **Theme**: light/dark is toggled in Settings → Appearance (no gesture).
- A black native splash with the centered logo shows on launch
  (`flutter_native_splash`, `assets/splash_logo.png`).
- Three dots at the bottom indicate which panel you're on.

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
