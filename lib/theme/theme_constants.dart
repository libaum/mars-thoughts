import 'package:flutter/material.dart';

/// Colors — pure black/white, following Mars design language
const COLOR_LIGHT_BACKGROUND = Colors.white;
const COLOR_LIGHT_PRIMARY = Colors.black;

const COLOR_DARK_BACKGROUND = Colors.black;
const COLOR_DARK_PRIMARY = Colors.white;

const COLOR_SECONDARY = Color(0xFF888888);

/// Font
const FONT_FAMILY = 'Outfit';

/// Text styles — fontFamily set via ThemeData, not per-style

/// The writing surface (center panel + edit screen)
// letterSpacing must be explicit: TextField merges this style onto
// theme.textTheme.bodyLarge, while SelectableText merges it onto the
// ambient DefaultTextStyle — those carry different default letter-spacing,
// which drifted edit and read mode text out of horizontal alignment.
const TEXT_STYLE_EDITOR = TextStyle(
  fontFamily: FONT_FAMILY,
  fontSize: 18,
  fontWeight: FontWeight.w300,
  height: 1.5,
  letterSpacing: 0,
  wordSpacing: 0,
);

/// Explicit strut for the writing surface. TextField and SelectableText default
/// to different strut leading, which drifted the line spacing between edit and
/// read mode. Forcing an identical strut keeps the two pixel-aligned vertically.
const STRUT_STYLE_EDITOR = StrutStyle(
  fontFamily: FONT_FAMILY,
  fontSize: 18,
  fontWeight: FontWeight.w300,
  height: 1.5,
  forceStrutHeight: true,
);

/// First line of a thought in a list
const TEXT_STYLE_THOUGHT_PREVIEW = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w300,
  height: 1.3,
);

/// Faint relative timestamp under a thought
const TEXT_STYLE_THOUGHT_TIME = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w300,
  color: COLOR_SECONDARY,
);

/// Quiet panel label ("Pinned", "All thoughts")
const TEXT_STYLE_PANEL_LABEL = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w400,
  letterSpacing: 1.2,
  color: COLOR_SECONDARY,
);

/// Search field input
const TEXT_STYLE_SEARCH_INPUT = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w300,
);

/// Empty-state / placeholder copy
const TEXT_STYLE_EMPTY = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w300,
  color: COLOR_SECONDARY,
);

/// Theme builders
ThemeData buildLightTheme() => ThemeData(
  colorScheme: const ColorScheme.light(
    surface: COLOR_LIGHT_BACKGROUND,
    primary: COLOR_LIGHT_PRIMARY,
    brightness: Brightness.light,
  ),
  fontFamily: FONT_FAMILY,
  scaffoldBackgroundColor: COLOR_LIGHT_BACKGROUND,
  brightness: Brightness.light,
  iconTheme: const IconThemeData(color: COLOR_LIGHT_PRIMARY),
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: COLOR_LIGHT_PRIMARY,
    selectionHandleColor: COLOR_SECONDARY,
  ),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: WidgetStateProperty.all<Color>(COLOR_LIGHT_PRIMARY),
      overlayColor: WidgetStateProperty.all<Color>(Colors.transparent),
    ),
  ),
);

ThemeData buildDarkTheme() => ThemeData(
  colorScheme: const ColorScheme.dark(
    surface: COLOR_DARK_BACKGROUND,
    primary: COLOR_DARK_PRIMARY,
    brightness: Brightness.dark,
  ),
  fontFamily: FONT_FAMILY,
  scaffoldBackgroundColor: COLOR_DARK_BACKGROUND,
  brightness: Brightness.dark,
  iconTheme: const IconThemeData(color: COLOR_DARK_PRIMARY),
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: COLOR_DARK_PRIMARY,
    selectionHandleColor: COLOR_SECONDARY,
  ),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: WidgetStateProperty.all<Color>(COLOR_DARK_PRIMARY),
      overlayColor: WidgetStateProperty.all<Color>(Colors.transparent),
    ),
  ),
);
