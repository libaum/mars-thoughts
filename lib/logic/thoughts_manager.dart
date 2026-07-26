import 'package:flutter/foundation.dart';
import 'package:mars_thoughts/data/local_storage_service.dart';
import 'package:mars_thoughts/domain/thought.dart';
import 'package:mars_thoughts/services/service_locator.dart';

/// Core state for the app: the list of captured thoughts.
///
/// Exposes a single source of truth (`thoughtsNotifier`, every stored thought)
/// and derives `active` / `pinned` / `trash` views from it. Deleting a thought
/// is non-destructive: it moves to the trash, where it can be restored or
/// purged. Every mutation persists immediately — no save button anywhere.
class ThoughtsManager {
  final _storage = getIt<LocalStorageService>();

  /// Every stored thought (live + trashed), sorted newest-updated first.
  late final ValueNotifier<List<Thought>> thoughtsNotifier;

  ThoughtsManager() {
    final thoughts = _storage.getThoughts();
    _sortByUpdated(thoughts);
    thoughtsNotifier = ValueNotifier(thoughts);
  }

  List<Thought> get _thoughts => thoughtsNotifier.value;

  /// Live thoughts (not in the trash), newest-updated first.
  List<Thought> get active =>
      _thoughts.where((t) => !t.isDeleted).toList();

  /// Trashed thoughts, most recently deleted first.
  List<Thought> get trash {
    final list = _thoughts.where((t) => t.isDeleted).toList();
    list.sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return list;
  }

  /// Pinned live thoughts, most recently pinned first.
  List<Thought> get pinned {
    final list =
        _thoughts.where((t) => t.isPinned && !t.isDeleted).toList();
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

  /// Moves a thought to the trash (recoverable). Unpins it on the way out so
  /// the trash never holds pinned items.
  void delete(String id) {
    final updated = _thoughts.map((t) {
      if (t.id != id) return t;
      return t.copyWith(deletedAt: DateTime.now(), clearPinned: true);
    }).toList();
    _commit(updated);
  }

  /// Brings a trashed thought back to life.
  void restore(String id) {
    final updated = _thoughts.map((t) {
      if (t.id != id) return t;
      return t.copyWith(clearDeleted: true);
    }).toList();
    _commit(updated);
  }

  /// Permanently removes a single trashed thought.
  void purge(String id) {
    _commit(_thoughts.where((t) => t.id != id).toList());
  }

  /// Permanently removes everything in the trash.
  void emptyTrash() {
    _commit(_thoughts.where((t) => !t.isDeleted).toList());
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
