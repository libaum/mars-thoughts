import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mars_thoughts/domain/thought.dart';
import 'package:mars_thoughts/theme/theme_constants.dart';
import 'package:mars_thoughts/util/highlight.dart';
import 'package:mars_thoughts/util/time_format.dart';

/// One thought in a list.
/// Tap → open, long-press → pin/unpin, swipe right → delete.
///
/// Swipe is deliberately one-directional (right only): a left swipe stays free
/// so it can page back to the Write panel. When [onDelete] is null the row has
/// no swipe-to-delete at all (used for the pinned list).
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

    // No delete here (e.g. pinned list) → plain row, both swipes free for paging.
    if (onDelete == null) return content;

    return _SwipeToDelete(onDelete: onDelete!, child: content);
  }
}

/// Swipe a row to the right to delete it. Unlike `Dismissible`, it only ever
/// claims *rightward* drags in the gesture arena — a leftward drag is rejected
/// and falls through to the parent `PageView`, so the list stays swipeable to
/// the Write panel.
class _SwipeToDelete extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;

  const _SwipeToDelete({required this.child, required this.onDelete});

  @override
  State<_SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<_SwipeToDelete> {
  static const _maxReveal = 180.0;
  static const _threshold = 96.0;

  double _drag = 0;

  void _onUpdate(DragUpdateDetails d) {
    setState(() => _drag = (_drag + d.delta.dx).clamp(0.0, _maxReveal));
  }

  void _onEnd(DragEndDetails d) {
    final delete = _drag >= _threshold;
    setState(() => _drag = 0);
    if (delete) widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        _RightwardDragRecognizer:
            GestureRecognizerFactoryWithHandlers<_RightwardDragRecognizer>(
          () => _RightwardDragRecognizer(),
          (instance) => instance
            ..onUpdate = _onUpdate
            ..onEnd = _onEnd,
        ),
      },
      child: Stack(
        children: [
          if (_drag > 0)
            Positioned.fill(
              child: Opacity(
                opacity: (_drag / _threshold).clamp(0.0, 1.0),
                child: const _DeleteHint(),
              ),
            ),
          Transform.translate(
            offset: Offset(_drag, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// A horizontal-drag recognizer that bows out the moment a drag heads left, so
/// the enclosing `PageView` wins leftward swipes while we keep rightward ones.
class _RightwardDragRecognizer extends HorizontalDragGestureRecognizer {
  Offset? _origin;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _origin = event.position;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent && _origin != null) {
      final dx = event.position.dx - _origin!.dx;
      // A drag heading left belongs to the PageView — bow out.
      if (dx < -kTouchSlop) {
        resolve(GestureDisposition.rejected);
        stopTrackingPointer(event.pointer);
        return;
      }
      // A clear rightward drag is ours: claim the arena now so it wins over
      // the enclosing PageView's own horizontal drag (which otherwise ties and
      // often swallows the swipe, making delete feel broken).
      if (dx > kTouchSlop) {
        resolve(GestureDisposition.accepted);
      }
    }
    super.handleEvent(event);
  }
}

/// Quiet delete affordance revealed behind a row swiped to the right.
class _DeleteHint extends StatelessWidget {
  const _DeleteHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, size: 16, color: COLOR_SECONDARY),
            SizedBox(width: 8),
            Text(
              'Delete',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: COLOR_SECONDARY,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
