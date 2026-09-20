import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mars_thoughts/data/local_storage_service.dart';
import 'package:mars_thoughts/domain/thought.dart';
import 'package:mars_thoughts/services/service_locator.dart';
import 'package:mars_thoughts/sync/sync_flags.dart';

/// Core state for the app: the list of captured thoughts.
///
/// Exposes a single source of truth (`thoughtsNotifier`, every stored thought)
/// and derives `active` / `pinned` / `trash` views from it. Deleting a thought
/// is non-destructive: it moves to the trash, where it can be restored or
/// purged. Every mutation persists immediately — no save button anywhere.
///
/// Every user-driven mutation stamps `changedAt` on the thoughts it touches;
/// that's the clock the personal flavor's sync layer orders edits by. Remote
/// edits come in through [applySynced], which deliberately leaves the stamps
/// it's given alone.
class ThoughtsManager {
  final _storage = getIt<LocalStorageService>();

  /// Whether purges leave a trace for the sync layer. Defaults to the build
  /// flavor; tests pass `true` explicitly since they run without a flavor.
  final bool _recordPurges;

  /// Every stored thought (live + trashed), sorted newest-updated first.
  late final ValueNotifier<List<Thought>> thoughtsNotifier;

  ThoughtsManager({bool recordPurges = kSyncEnabled})
      : _recordPurges = recordPurges {
    final thoughts = _storage.getThoughts();
    _sortByUpdated(thoughts);
    thoughtsNotifier = ValueNotifier(thoughts);
  }

  List<Thought> get _thoughts => thoughtsNotifier.value;

  /// Live thoughts (not in the trash), newest-updated first.
  List<Thought> get active => _thoughts.where((t) => !t.isDeleted).toList();

  /// Trashed thoughts, most recently deleted first.
  List<Thought> get trash {
    final list = _thoughts.where((t) => t.isDeleted).toList();
    list.sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return list;
  }

  /// Pinned live thoughts, most recently pinned first.
  List<Thought> get pinned {
    final list = _thoughts.where((t) => t.isPinned && !t.isDeleted).toList();
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
      changedAt: now,
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
    final now = DateTime.now();
    final updated = _thoughts.map((t) {
      if (t.id != id) return t;
      if (t.text == text) return t;
      return t.copyWith(text: text, updatedAt: now, changedAt: now);
    }).toList();
    _commit(updated);
  }

  /// Moves a thought to the trash (recoverable). Unpins it on the way out so
  /// the trash never holds pinned items.
  void delete(String id) {
    final now = DateTime.now();
    final updated = _thoughts.map((t) {
      if (t.id != id) return t;
      return t.copyWith(deletedAt: now, changedAt: now, clearPinned: true);
    }).toList();
    _commit(updated);
  }

  /// Brings a trashed thought back to life.
  void restore(String id) {
    final now = DateTime.now();
    final updated = _thoughts.map((t) {
      if (t.id != id) return t;
      return t.copyWith(clearDeleted: true, changedAt: now);
    }).toList();
    _commit(updated);
  }

  /// Permanently removes a single trashed thought.
  void purge(String id) {
    _recordPurged({id});
    _commit(_thoughts.where((t) => t.id != id).toList());
  }

  /// Permanently removes everything in the trash.
  void emptyTrash() {
    _recordPurged(_thoughts.where((t) => t.isDeleted).map((t) => t.id).toSet());
    _commit(_thoughts.where((t) => !t.isDeleted).toList());
  }

  /// Pins an unpinned thought / unpins a pinned one.
  void togglePin(String id) {
    final now = DateTime.now();
    final updated = _thoughts.map((t) {
      if (t.id != id) return t;
      return t.isPinned
          ? t.copyWith(clearPinned: true, changedAt: now)
          : t.copyWith(pinnedAt: now, changedAt: now);
    }).toList();
    _commit(updated);
  }

  /// Pins every one of [ids] if any of them is unpinned, otherwise unpins
  /// all of them — so applying it twice in a row is never a no-op.
  void togglePinMany(Set<String> ids) {
    final now = DateTime.now();
    final pinAll = _thoughts.any((t) => ids.contains(t.id) && !t.isPinned);
    final updated = _thoughts.map((t) {
      if (!ids.contains(t.id)) return t;
      return pinAll
          ? t.copyWith(pinnedAt: now, changedAt: now)
          : t.copyWith(clearPinned: true, changedAt: now);
    }).toList();
    _commit(updated);
  }

  /// Moves every one of [ids] to the trash (recoverable), unpinning each.
  void deleteMany(Set<String> ids) {
    final now = DateTime.now();
    final updated = _thoughts.map((t) {
      if (!ids.contains(t.id)) return t;
      return t.copyWith(deletedAt: now, changedAt: now, clearPinned: true);
    }).toList();
    _commit(updated);
  }

  /// Writes the outcome of a sync round: [upserts] replace or add thoughts
  /// by id exactly as given (their `changedAt` is the remote device's, not
  /// now), [removed] maps ids purged elsewhere to when that happened.
  ///
  /// Anything changed locally *after* the incoming stamp is left alone: the
  /// sync engine resolved conflicts against a snapshot from the start of its
  /// round, and the user may well have typed, pinned or trashed something
  /// while the network round trip was in flight.
  void applySynced(List<Thought> upserts, Map<String, DateTime> removed) {
    if (upserts.isEmpty && removed.isEmpty) return;
    final byId = {for (final t in _thoughts) t.id: t};
    var changed = false;
    for (final t in upserts) {
      final existing = byId[t.id];
      if (existing != null) {
        if (existing.changedAt.isAfter(t.changedAt)) continue;
        // Our own push coming back from the hub: same stamp, same content.
        // Rewriting it would only churn storage and the UI.
        if (existing.changedAt.isAtSameMomentAs(t.changedAt) &&
            jsonEncode(existing.toJson()) == jsonEncode(t.toJson())) {
          continue;
        }
      }
      byId[t.id] = t;
      changed = true;
    }
    for (final entry in removed.entries) {
      final existing = byId[entry.key];
      if (existing == null) continue;
      if (existing.changedAt.isAfter(entry.value)) continue;
      byId.remove(entry.key);
      changed = true;
    }
    if (changed) _commit(byId.values.toList());
  }

  /// Remembers purged ids so the sync layer can still tell other devices
  /// about them after the thoughts themselves are gone from the list.
  void _recordPurged(Set<String> ids) {
    if (!_recordPurges || ids.isEmpty) return;
    final purged = _storage.getSyncPurged();
    final now = DateTime.now();
    for (final id in ids) {
      purged[id] = now;
    }
    _storage.setSyncPurged(purged);
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
