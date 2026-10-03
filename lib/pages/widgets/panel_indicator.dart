import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mars_thoughts/theme/theme_constants.dart';

/// Four short vertical strokes on the right edge, one per panel on the
/// filmstrip (Settings, Pinned, Write, All — top to bottom, the same order the
/// panels are stacked in). The stroke for [position] is drawn in the
/// foreground colour, the others in gray; between two panels both blend, so
/// the indicator travels with the drag.
///
/// It behaves like a scrollbar, not a page indicator: [visible] is only true
/// while navigating and for a moment after landing — at rest, Write stays a
/// blank page. See `MainScreen._showIndicator`.
class PanelIndicator extends StatelessWidget {
  final ValueListenable<double> position;
  final ValueListenable<bool> visible;
  final List<double> slots;

  const PanelIndicator({
    super.key,
    required this.position,
    required this.visible,
    required this.slots,
  });

  static const _strokeWidth = 2.0;
  static const _strokeHeight = 14.0;
  static const _gap = 6.0;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return IgnorePointer(
      child: ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (context, visible, child) => AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: Duration(milliseconds: visible ? 120 : 400),
          child: child,
        ),
        child: ValueListenableBuilder<double>(
          valueListenable: position,
          builder: (context, position, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final slot in slots)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: _gap / 2),
                  child: Container(
                    width: _strokeWidth,
                    height: _strokeHeight,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        primary,
                        COLOR_SECONDARY.withValues(alpha: 0.5),
                        (slot - position).abs().clamp(0.0, 1.0),
                      ),
                      borderRadius: BorderRadius.circular(_strokeWidth / 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
