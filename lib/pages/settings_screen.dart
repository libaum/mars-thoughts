import 'package:flutter/material.dart';
import 'package:mars_thoughts/pages/about_screen.dart';
import 'package:mars_thoughts/pages/trash_screen.dart';
import 'package:mars_thoughts/services/service_locator.dart';
import 'package:mars_thoughts/theme/theme_constants.dart';
import 'package:mars_thoughts/theme/theme_manager.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final themeManager = getIt<ThemeManager>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  color: primary,
                ),
              ),
            ),
            const SizedBox(height: 40),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeManager.themeModeNotifier,
              builder: (context, _, _) {
                final isDark =
                    Theme.of(context).brightness == Brightness.dark;
                return _NavRow(
                  label: 'Appearance',
                  trailing: isDark ? 'Dark' : 'Light',
                  onTap: themeManager.toggleTheme,
                );
              },
            ),
            _Divider(),
            _NavRow(
              label: 'Trash',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TrashScreen()),
              ),
            ),
            _Divider(),
            _NavRow(
              label: 'About',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              ),
            ),
            _Divider(),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  color: primary,
                ),
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  trailing!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    color: COLOR_SECONDARY,
                  ),
                ),
              )
            else
              Icon(Icons.chevron_right,
                  size: 20, color: primary.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Divider(
      height: 1,
      thickness: 0.5,
      color: primary.withValues(alpha: 0.1),
      indent: 32,
      endIndent: 32,
    );
  }
}
