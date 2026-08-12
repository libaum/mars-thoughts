import 'package:flutter/material.dart';
import 'package:mars_thoughts/data/local_storage_service.dart';
import 'package:mars_thoughts/services/service_locator.dart';
import 'package:mars_thoughts/theme/theme_constants.dart';

/// Manages dark/light theme, following the Mars pattern.
class ThemeManager {
  final _storage = getIt<LocalStorageService>();

  late final ValueNotifier<ThemeMode> themeModeNotifier;

  late final ValueNotifier<Color> lightBackgroundNotifier;
  late final ValueNotifier<Color> darkBackgroundNotifier;

  ThemeManager() {
    final isDark = _storage.getThemeIsDark();
    // No preference yet (fresh install): default to dark rather than
    // following the system, so Appearance always reads "Dark" until the
    // user explicitly switches it.
    themeModeNotifier = ValueNotifier(
      isDark ?? true ? ThemeMode.dark : ThemeMode.light,
    );

    final lightArgb = _storage.getLightBackground();
    lightBackgroundNotifier = ValueNotifier(
      lightArgb == null ? COLOR_LIGHT_BACKGROUND : Color(lightArgb),
    );
    final darkArgb = _storage.getDarkBackground();
    darkBackgroundNotifier = ValueNotifier(
      darkArgb == null ? COLOR_DARK_BACKGROUND : Color(darkArgb),
    );
  }

  void toggleTheme() {
    if (themeModeNotifier.value == ThemeMode.dark) {
      themeModeNotifier.value = ThemeMode.light;
    } else {
      // Both system and light → dark
      themeModeNotifier.value = ThemeMode.dark;
    }
    _storage.setThemeIsDark(themeModeNotifier.value == ThemeMode.dark);
  }

  void setLightBackground(Color? color) {
    lightBackgroundNotifier.value = color ?? COLOR_LIGHT_BACKGROUND;
    _storage.setLightBackground(color?.toARGB32());
  }

  void setDarkBackground(Color? color) {
    darkBackgroundNotifier.value = color ?? COLOR_DARK_BACKGROUND;
    _storage.setDarkBackground(color?.toARGB32());
  }

  ThemeData get lightTheme =>
      buildLightTheme(background: lightBackgroundNotifier.value);
  ThemeData get darkTheme =>
      buildDarkTheme(background: darkBackgroundNotifier.value);
}
