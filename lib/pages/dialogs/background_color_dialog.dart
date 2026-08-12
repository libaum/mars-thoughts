import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:mars_thoughts/services/service_locator.dart';
import 'package:mars_thoughts/theme/theme_constants.dart';
import 'package:mars_thoughts/theme/theme_manager.dart';

/// Lets the user tint the write surface's background instead of pure
/// black/white — one gray preset row plus a full picker for a custom shade.
/// Every pick applies live behind the dialog as a preview; only "Cancel"
/// (including back/barrier dismiss) reverts to the color it was opened with.
class BackgroundColorDialog extends StatefulWidget {
  final bool isDark;

  const BackgroundColorDialog({super.key, required this.isDark});

  @override
  State<BackgroundColorDialog> createState() => _BackgroundColorDialogState();
}

class _BackgroundColorDialogState extends State<BackgroundColorDialog> {
  final _themeManager = getIt<ThemeManager>();

  late Color _selectedColor;
  late final Color _originalColor;
  bool _confirmed = false;

  List<Color> get _presets =>
      widget.isDark ? DARK_BACKGROUND_PRESETS : LIGHT_BACKGROUND_PRESETS;

  @override
  void initState() {
    super.initState();
    _originalColor = widget.isDark
        ? _themeManager.darkBackgroundNotifier.value
        : _themeManager.lightBackgroundNotifier.value;
    _selectedColor = _originalColor;
  }

  void _preview(Color color) {
    setState(() => _selectedColor = color);
    _apply(color);
  }

  void _apply(Color? color) {
    if (widget.isDark) {
      _themeManager.setDarkBackground(color);
    } else {
      _themeManager.setLightBackground(color);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_confirmed) _apply(_originalColor);
      },
      child: AlertDialog(
        title: Text(
          'Background color',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w300,
            color: primary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _presets
                    .map(
                      (color) => GestureDetector(
                        onTap: () => _preview(color),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedColor == color
                                  ? primary
                                  : COLOR_SECONDARY,
                              width: _selectedColor == color ? 2.5 : 1,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              ColorPicker(
                pickerColor: _selectedColor,
                onColorChanged: _preview,
                labelTypes: const [],
                enableAlpha: false,
                pickerAreaHeightPercent: 0.7,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _confirmed = true;
              _apply(null);
              Navigator.of(context).pop();
            },
            child: Text(
              'Reset',
              style: TextStyle(color: primary.withValues(alpha: 0.6)),
            ),
          ),
          TextButton(
            onPressed: () {
              _confirmed = true;
              Navigator.of(context).pop();
            },
            child: Text('Done', style: TextStyle(color: primary)),
          ),
        ],
      ),
    );
  }
}
