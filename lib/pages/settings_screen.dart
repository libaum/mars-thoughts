import 'package:flutter/material.dart';
import 'package:mars_thoughts/pages/about_screen.dart';
import 'package:mars_thoughts/pages/trash_screen.dart';
import 'package:mars_thoughts/services/service_locator.dart';
import 'package:mars_thoughts/theme/theme_constants.dart';
import 'package:mars_thoughts/theme/theme_manager.dart';

/// Reached by pulling down past the top of the pinned list, so it leaves the
/// same way it came: swipe **up** and it lifts off, back to Pinned. The system
/// back button works too.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _swipeUpThreshold = 96.0;

  double _dragUp = 0;
  bool _popping = false;

  /// Only upward travel counts — pulling down would mean going further into
  /// the app, and there is nothing beyond Settings.
  void _onDragUpdate(DragUpdateDetails d) {
    setState(() => _dragUp = (_dragUp - d.delta.dy).clamp(0.0, 200.0));
  }

  void _onDragEnd(DragEndDetails d) {
    final shouldPop = _dragUp >= _swipeUpThreshold;
    setState(() => _dragUp = 0);
    if (shouldPop && !_popping) {
      _popping = true;
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final themeManager = getIt<ThemeManager>();

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          child: Transform.translate(
            offset: Offset(0, -_dragUp),
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
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    return _NavRow(
                      label: 'Appearance',
                      trailing: isDark ? 'Dark' : 'Light',
                      onTap: themeManager.toggleTheme,
                    );
                  },
                ),
                _NavRow(
                  label: 'Trash',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TrashScreen()),
                  ),
                ),
                _NavRow(
                  label: 'About',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  ),
                ),
              ],
            ),
          ),
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
