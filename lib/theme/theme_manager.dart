import 'package:flutter/material.dart';
import 'package:mars_thoughts/data/local_storage_service.dart';
import 'package:mars_thoughts/services/service_locator.dart';
import 'package:mars_thoughts/theme/theme_constants.dart';

/// Manages dark/light theme, following the Mars pattern.
class ThemeManager {
  final _storage = getIt<LocalStorageService>();

  late final ValueNotifier<ThemeMode> themeModeNotifier;

  ThemeManager() {
    final isDark = _storage.getThemeIsDark();
    if (isDark == null) {
      themeModeNotifier = ValueNotifier(ThemeMode.system);
    } else {
      themeModeNotifier = ValueNotifier(isDark ? ThemeMode.dark : ThemeMode.light);
    }
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

  ThemeData get lightTheme => buildLightTheme();
  ThemeData get darkTheme => buildDarkTheme();
}
