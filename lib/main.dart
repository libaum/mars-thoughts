import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mars_thoughts/pages/main_screen.dart';
import 'package:mars_thoughts/services/service_locator.dart';
import 'package:mars_thoughts/theme/theme_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await setupServiceLocator();
  runApp(const MarsThoughts());
}

class MarsThoughts extends StatelessWidget {
  const MarsThoughts({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = getIt<ThemeManager>();

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeManager.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Mars Thoughts',
          theme: themeManager.lightTheme,
          darkTheme: themeManager.darkTheme,
          themeMode: themeMode,
          // Make the Android status & navigation bars follow the resolved theme
          // (black on dark, white on light) instead of staying a stray grey.
          // Runs below the theme, so `system` mode is resolved correctly here.
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final iconBrightness =
                isDark ? Brightness.light : Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: iconBrightness,
                statusBarBrightness:
                    isDark ? Brightness.dark : Brightness.light,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarIconBrightness: iconBrightness,
                systemNavigationBarContrastEnforced: false,
              ),
              child: child!,
            );
          },
          home: const MainScreen(),
        );
      },
    );
  }
}
