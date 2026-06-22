import 'package:flutter/material.dart';
import 'package:mars_thoughts/pages/widgets/double_tap_theme_toggle.dart';
import 'package:mars_thoughts/theme/theme_constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return DoubleTapThemeToggle(
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mars Thoughts',
                  style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w300, color: primary),
                ),
                const SizedBox(height: 32),
                Text(
                  'A place for thoughts to land before they disappear.',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w300,
                      color: primary,
                      height: 1.7),
                ),
                const SizedBox(height: 24),
                Text(
                  'Open. Type. Close.\nNo titles, no folders, no save button.',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w300,
                      color: primary,
                      height: 1.7),
                ),
                const SizedBox(height: 24),
                const Text(
                  'No ads. No tracking. No accounts.\nYour thoughts never leave the device.',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w300,
                      color: COLOR_SECONDARY,
                      height: 1.7),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Part of the Mars product family.',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      color: COLOR_SECONDARY,
                      height: 1.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
