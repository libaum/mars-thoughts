import 'package:flutter/material.dart';
import 'package:mars_thoughts/domain/thought.dart';
import 'package:mars_thoughts/logic/thoughts_manager.dart';
import 'package:mars_thoughts/services/service_locator.dart';
import 'package:mars_thoughts/theme/theme_constants.dart';
import 'package:mars_thoughts/util/time_format.dart';

/// Deleted thoughts live here until they're restored or removed for good.
/// Restore brings a thought back to the list; delete is permanent.
class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = getIt<ThoughtsManager>();
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<List<Thought>>(
          valueListenable: manager.thoughtsNotifier,
          builder: (context, _, _) {
            final trash = manager.trash;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Trash',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w300,
                            color: primary,
                          ),
                        ),
                      ),
                      if (trash.isNotEmpty)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: manager.emptyTrash,
                          child: const Text(
                            'Empty',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w300,
                              color: COLOR_SECONDARY,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: trash.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              'Trash is empty',
                              style: TEXT_STYLE_EMPTY,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: trash.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            thickness: 0.5,
                            color: primary.withValues(alpha: 0.08),
                            indent: 32,
                            endIndent: 32,
                          ),
                          itemBuilder: (context, index) {
                            final thought = trash[index];
                            return _TrashRow(
                              thought: thought,
                              onRestore: () => manager.restore(thought.id),
                              onPurge: () => manager.purge(thought.id),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TrashRow extends StatelessWidget {
  final Thought thought;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

  const _TrashRow({
    required this.thought,
    required this.onRestore,
    required this.onPurge,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
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
                  style: TEXT_STYLE_THOUGHT_PREVIEW.copyWith(
                    color: primary.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatThoughtTime(thought.deletedAt!),
                  style: TEXT_STYLE_THOUGHT_TIME,
                ),
              ],
            ),
          ),
          _IconAction(icon: Icons.restore, onTap: onRestore),
          const SizedBox(width: 4),
          _IconAction(icon: Icons.delete_outline, onTap: onPurge),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Icon(icon, size: 20, color: COLOR_SECONDARY),
      ),
    );
  }
}
