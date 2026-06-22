import 'package:flutter/material.dart';
import 'package:mars_thoughts/domain/thought.dart';
import 'package:mars_thoughts/theme/theme_constants.dart';
import 'package:mars_thoughts/util/time_format.dart';

/// One thought in a list.
/// Tap → edit, long-press → pin/unpin, swipe left → delete.
class ThoughtRow extends StatelessWidget {
  final Thought thought;
  final bool showPinIcon;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDismissed;

  const ThoughtRow({
    super.key,
    required this.thought,
    required this.showPinIcon,
    required this.onTap,
    required this.onLongPress,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Dismissible(
      key: ValueKey('dismiss_${thought.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      child: GestureDetector(
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
                    Text(
                      thought.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TEXT_STYLE_THOUGHT_PREVIEW.copyWith(color: primary),
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
      ),
    );
  }
}
