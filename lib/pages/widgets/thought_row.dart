import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mars_thoughts/domain/thought.dart';
import 'package:mars_thoughts/theme/theme_constants.dart';
import 'package:mars_thoughts/util/highlight.dart';
import 'package:mars_thoughts/util/time_format.dart';

/// One thought in a list.
/// Tap → open, long-press → pin/unpin, swipe left → delete, swipe right → copy.
///
/// Navigation between panels is vertical, so the row's horizontal axis is free
/// for both swipe directions. When [onDelete] is null the row has no swipe
/// actions at all (used for the pinned list, which unpins instead).
///
/// When [query] is set the row shows the matching part of the thought with the
/// query highlighted, so a search result is recognisable at a glance.
class ThoughtRow extends StatelessWidget {
  final Thought thought;
  final bool showPinIcon;
  final String query;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onDelete;

  const ThoughtRow({
    super.key,
    required this.thought,
    required this.showPinIcon,
    required this.onTap,
    required this.onLongPress,
    this.onDelete,
    this.query = '',
  });

  /// Up to three lines to show: the first non-empty lines normally, or a window
  /// starting at the first matching line while searching.
  List<String> _displayLines() {
    final lines = thought.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return const [];
    if (query.isEmpty) return lines.take(2).toList();
    final start = lines.indexWhere((l) => l.toLowerCase().contains(query));
    return lines.skip(start < 0 ? 0 : start).take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final searching = query.isNotEmpty;
    final lines = _displayLines();

    // Normal: the first line reads as the title (full strength), the rest is
    // dimmed context. Searching: dim everything but the matched term so the
    // query pops out of whichever line it lives on.
    final titleStyle = TEXT_STYLE_THOUGHT_PREVIEW.copyWith(color: primary);
    final dimStyle = TEXT_STYLE_THOUGHT_PREVIEW.copyWith(
      color: primary.withValues(alpha: 0.5),
    );
    final matchStyle = TEXT_STYLE_THOUGHT_PREVIEW.copyWith(
      color: primary,
      fontWeight: FontWeight.w500,
    );

    final List<InlineSpan> spans;
    if (searching) {
      spans = highlightSpans(
        lines.join('\n'),
        query,
        baseStyle: dimStyle,
        matchStyle: matchStyle,
      );
    } else {
      spans = [
        TextSpan(text: lines.isEmpty ? '' : lines.first, style: titleStyle),
        if (lines.length > 1)
          TextSpan(text: '\n${lines.skip(1).join('\n')}', style: dimStyle),
      ];
    }

    final content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: spans),
                    maxLines: searching ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatThoughtTime(thought.updatedAt),
                    style: TEXT_STYLE_THOUGHT_TIME,
                  ),
                ],
              ),
            ),
            if (showPinIcon && thought.isPinned)
              const Padding(
                padding: EdgeInsets.only(left: 12, top: 2),
                child: Icon(Icons.push_pin, size: 13, color: COLOR_SECONDARY),
              ),
          ],
        ),
      ),
    );

    // No delete here (e.g. pinned list) → plain row, no swipe actions.
    if (onDelete == null) return content;

    return _SwipeActions(
      onDelete: onDelete!,
      // No extra haptic here — hitting the stop already ticked.
      onCopy: () => Clipboard.setData(ClipboardData(text: thought.text)),
      child: content,
    );
  }
}

/// Swipe a row left to delete it, right to copy its text to the clipboard.
class _SwipeActions extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;
  final VoidCallback onCopy;

  const _SwipeActions({
    required this.child,
    required this.onDelete,
    required this.onCopy,
  });

  @override
  State<_SwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<_SwipeActions> {
  /// How far a row may travel, as a fraction of its width.
  static const _maxRevealFraction = 1 / 3;
  static const _iconSize = 20.0;

  /// Set from the LayoutBuilder below — the travel limit is width-relative.
  double _maxReveal = 0;

  double _drag = 0;

  /// True once the row is pulled all the way to the stop. Only then does
  /// releasing it do anything — a half-hearted swipe is always a no-op, so
  /// nothing is ever deleted by a hesitant thumb. Hitting the stop ticks once
  /// so you can feel that the action is loaded without looking.
  bool _armed = false;

  void _onUpdate(DragUpdateDetails d) {
    final drag = (_drag + d.delta.dx).clamp(-_maxReveal, _maxReveal);
    final armed = _maxReveal > 0 && drag.abs() >= _maxReveal - 0.5;
    if (armed && !_armed) HapticFeedback.mediumImpact();
    setState(() {
      _drag = drag;
      _armed = armed;
    });
  }

  void _onEnd(DragEndDetails d) {
    final delete = _armed && _drag < 0;
    final copy = _armed && _drag > 0;
    setState(() {
      _drag = 0;
      _armed = false;
    });
    if (delete) widget.onDelete();
    if (copy) widget.onCopy();
  }

  @override
  Widget build(BuildContext context) {
    // The row reads as a tile in the background colour. Swiping it aside
    // uncovers an inverted tile filling exactly the strip it vacated —
    // delete tints red, copy stays in the neutral primary colour.
    final tile = Theme.of(context).scaffoldBackgroundColor;
    final reveal = _drag < 0
        ? COLOR_DELETE
        : Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        _maxReveal = constraints.maxWidth * _maxRevealFraction;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _onUpdate,
          onHorizontalDragEnd: _onEnd,
          child: Stack(
            children: [
              if (_drag != 0)
                Positioned(
                  // Flush with the edge the row started at, so the two tiles
                  // meet without a seam.
                  left: _drag > 0 ? 0 : null,
                  right: _drag < 0 ? 0 : null,
                  top: 0,
                  bottom: 0,
                  width: _drag.abs(),
                  child: ClipRect(
                    child: ColoredBox(
                      color: reveal,
                      // OverflowBox keeps the icon at full size and centred in
                      // the strip, so early in a swipe it is cut off by the
                      // strip's edges rather than squeezed into it.
                      child: OverflowBox(
                        minWidth: 0,
                        maxWidth: double.infinity,
                        child: Icon(
                          _drag < 0
                              ? Icons.delete_outline
                              : Icons.copy_outlined,
                          size: _iconSize,
                          color: tile,
                        ),
                      ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(_drag, 0),
                child: ColoredBox(color: tile, child: widget.child),
              ),
            ],
          ),
        );
      },
    );
  }
}
