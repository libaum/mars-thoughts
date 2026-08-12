import 'package:flutter/material.dart';
import 'package:mars_thoughts/data/local_storage_service.dart';
import 'package:mars_thoughts/pages/about_screen.dart';
import 'package:mars_thoughts/pages/dialogs/background_color_dialog.dart';
import 'package:mars_thoughts/pages/trash_screen.dart';
import 'package:mars_thoughts/services/service_locator.dart';
import 'package:mars_thoughts/theme/theme_constants.dart';
import 'package:mars_thoughts/theme/theme_manager.dart';
import 'package:mars_thoughts/util/instant_route.dart';

/// The topmost panel on `MainScreen`'s vertical axis, reached by pulling past
/// the top of the pinned list. Positioned and dragged by `MainScreen` exactly
/// like Pinned/Write/All — this widget owns no navigation or drag logic of
/// its own, only its own rows' content and taps.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = getIt<LocalStorageService>();

  late bool _animationsEnabled = _storage.getAnimationsEnabled();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final themeManager = getIt<ThemeManager>();

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 0, 50, 0),
            child: Text(
              'Settings',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w300,
                color: primary,
              ),
            ),
          ),
          const SizedBox(height: 40),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeManager.themeModeNotifier,
            builder: (context, _, _) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return _NavRow(
                label: 'Appearance',
                trailing: isDark ? 'Dark' : 'Light',
                onTap: themeManager.toggleTheme,
              );
            },
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeManager.themeModeNotifier,
            builder: (context, _, _) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return _NavRow(
                label: 'Background color',
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => BackgroundColorDialog(isDark: isDark),
                ),
              );
            },
          ),
          _NavRow(
            label: 'Animations',
            trailing: _animationsEnabled ? 'On' : 'Off',
            onTap: () {
              setState(() => _animationsEnabled = !_animationsEnabled);
              _storage.setAnimationsEnabled(_animationsEnabled);
            },
          ),
          _NavRow(
            label: 'Trash',
            onTap: () =>
                Navigator.push(context, instantRoute((_) => const TrashScreen())),
          ),
          _NavRow(
            label: 'About',
            onTap: () =>
                Navigator.push(context, instantRoute((_) => const AboutScreen())),
          ),
          // MainScreen's own SafeArea only insets the top; each panel carries
          // its own bottom inset, same as the thought lists.
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  const _NavRow({required this.label, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 20, 50, 20),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w300,
                  color: primary,
                ),
              ),
            ),
            SizedBox(
              width: 60,
              child: Center(
                child: trailing != null
                    ? Text(
                        trailing!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                          color: COLOR_SECONDARY,
                        ),
                      )
                    : Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: primary.withValues(alpha: 0.3),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
