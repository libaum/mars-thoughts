# CLAUDE.md

This file provides guidance when working with code in this repository.

## Project Overview

Mars Thoughts is a minimal Flutter Android app for capturing fleeting thoughts.
Its single job: **get a thought out of your head and saved with the least
possible friction.** Not notes, not a wiki, not knowledge management — thoughts
that you want to hold onto before they disappear. Part of the Mars product family.

The app opens straight into a blank editor with the cursor blinking. You type,
you leave, it's saved. There is no save button anywhere.

## Common Commands

```bash
flutter run            # Run app
flutter test           # Run tests
flutter analyze        # Lint / static analysis
./install_debug.sh     # Debug (app: "Mars Thoughts Debug", pkg: com.catchingclouds.marsthoughts.debug)
./install_release.sh   # Release (app: "Mars Thoughts", pkg: com.catchingclouds.marsthoughts)
```

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
| `Thought` (`domain/`) | Immutable model: id, text, createdAt, updatedAt, pinnedAt. `preview` = first non-empty line. |
| `LocalStorageService` (`data/`) | SharedPreferences wrapper — JSON list of thoughts + theme flag. |
| `ThoughtsManager` (`logic/`) | Single source of truth (`thoughtsNotifier`, newest first). Derives `pinned`. Create/update/delete/togglePin, each persists immediately. |
| `ThemeManager` (`theme/`) | Light/dark, double-tap toggle, follows system by default. |

## Screens & Interactions

`MainScreen` is a 3-page `PageView` (opens on the center Write page):

```
  ← Pinned            Write (center)         All thoughts →
  pinned thoughts     blank editor,          search + chronological list
                      autofocus cursor       (newest first)
```

- **Write panel**: a single full-screen `TextField`. Leaving the page or
  backgrounding the app commits the draft as a new thought (if non-empty) and
  clears the editor, so it's always blank on return. See `_commitDraft`.
- **Tap** a thought → `ThoughtEditScreen` (full-screen editor, auto-saves on
  pop / app pause; emptying the text deletes the thought).
- **Long-press** a thought → toggle pin.
- **Swipe left** a thought → delete (no confirmation).
- **Long-press empty list area** → Settings (`_PanelBackground`). No gear icon.
- **Double-tap anywhere** → toggle light/dark (`DoubleTapThemeToggle`).
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
