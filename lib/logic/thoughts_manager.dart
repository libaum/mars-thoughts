import 'package:flutter/foundation.dart';
import 'package:mars_thoughts/data/local_storage_service.dart';
import 'package:mars_thoughts/domain/thought.dart';
import 'package:mars_thoughts/services/service_locator.dart';

/// Core state for the app: the list of captured thoughts.
///
/// Exposes a single source of truth (`thoughtsNotifier`, newest first) and
/// derives `pinned` / `unpinned` views from it. Every mutation persists
/// immediately — there is no save button anywhere in the app.
class ThoughtsManager {
  final _storage = getIt<LocalStorageService>();

  /// All thoughts, sorted newest-updated first.
  late final ValueNotifier<List<Thought>> thoughtsNotifier;

  ThoughtsManager() {
    final thoughts = _storage.getThoughts();
    _sortByUpdated(thoughts);
    thoughtsNotifier = ValueNotifier(thoughts);
  }

  List<Thought> get _thoughts => thoughtsNotifier.value;

  /// Pinned thoughts, most recently pinned first.
  List<Thought> get pinned {
    final list = _thoughts.where((t) => t.isPinned).toList();
    list.sort((a, b) => b.pinnedAt!.compareTo(a.pinnedAt!));
    return list;
  }

  /// Creates a thought from raw editor text. Empty text is ignored (no junk).
  /// Returns the created thought, or `null` if nothing was saved.
  Thought? create(String text) {
    if (text.trim().isEmpty) return null;
    final now = DateTime.now();
    final thought = Thought(
      id: now.microsecondsSinceEpoch.toString(),
      text: text,
      createdAt: now,
      updatedAt: now,
    );
    _commit([thought, ..._thoughts]);
    return thought;
  }

  /// Updates an existing thought's text. If the text becomes empty, the
  /// thought is deleted instead.
  void update(String id, String text) {
    if (text.trim().isEmpty) {
      delete(id);
      return;
    }
    final updated = _thoughts.map((t) {
      if (t.id != id) return t;
      if (t.text == text) return t;
      return t.copyWith(text: text, updatedAt: DateTime.now());
    }).toList();
    _commit(updated);
  }

  void delete(String id) {
    _commit(_thoughts.where((t) => t.id != id).toList());
  }

  /// Pins an unpinned thought / unpins a pinned one.
  void togglePin(String id) {
    final updated = _thoughts.map((t) {
      if (t.id != id) return t;
      return t.isPinned
          ? t.copyWith(clearPinned: true)
          : t.copyWith(pinnedAt: DateTime.now());
    }).toList();
    _commit(updated);
  }

  /// Sorts, persists, and publishes a new thought list.
  void _commit(List<Thought> thoughts) {
    _sortByUpdated(thoughts);
    _storage.setThoughts(thoughts);
    thoughtsNotifier.value = thoughts;
  }

  void _sortByUpdated(List<Thought> thoughts) {
    thoughts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
}
