# Mars Thoughts

Capture a thought before it disappears.

Mars Thoughts opens straight into a blank editor with the cursor blinking. You type, you leave, it's saved — no titles, no folders, no save button. Not notes, not a wiki: just somewhere for fleeting thoughts to land.

## Features

- **Opens to write** — the app launches directly into the editor, ready for the next thought
- **Auto-save** — leaving the editor or backgrounding the app saves it; empty drafts are discarded
- **Three panels** — swipe between Pinned ← Write → All thoughts
- **Pin what matters** — long-press a thought to keep it close
- **Swipe to delete** — swipe left, no confirmation
- **Search** — find any thought by its text
- **Light & dark mode** — double-tap anywhere to toggle; follows system by default
- **Offline & private** — everything stays on the device. No accounts, no tracking, no ads.

## Interactions

| Gesture | Action |
|---|---|
| Open app | Blank editor, cursor blinking |
| Swipe left/right | Move between Pinned, Write, All thoughts |
| Tap a thought | Edit it (full screen) |
| Long-press a thought | Pin / unpin |
| Swipe left on a thought | Delete |
| Long-press empty list area | Settings |
| Double-tap anywhere | Toggle light / dark |

## Install

```bash
# Debug (installs as "Mars Thoughts Debug")
./install_debug.sh

# Release (installs as "Mars Thoughts")
./install_release.sh
```

## Tech Stack

- Flutter / Dart
- GetIt (dependency injection)
- ValueNotifier + ValueListenableBuilder (state)
- SharedPreferences (local persistence)

## Design

Part of the Mars product family. Pure black & white, Outfit font, light weights, no visual clutter.

## License

MIT
