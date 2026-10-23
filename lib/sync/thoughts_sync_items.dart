import 'package:mars_sync/mars_sync.dart';
import 'package:mars_sync_flutter/mars_sync_flutter.dart';
import 'package:mars_thoughts/domain/thought.dart';
import 'package:mars_thoughts/logic/thoughts_manager.dart';

/// Maps the app's thoughts onto mars_sync's generic [SyncItem]s.
///
/// The whole [Thought] (including its trash state) rides along as the
/// payload, ordered by `changedAt`. A *purge* — permanent removal from the
/// trash — is the only thing that becomes a tombstone, pushed by the
/// [SyncLedger] the manager reports it to; moving to the trash is just an
/// ordinary edit, so it syncs like one and is restorable everywhere.
class ThoughtsSyncItems extends ModuleItems {
  static const _moduleId = 'mars_thoughts';

  final ThoughtsManager _manager;
  final String _deviceId;

  ThoughtsSyncItems({
    required ThoughtsManager manager,
    required String deviceId,
  })  : _manager = manager,
        _deviceId = deviceId;

  @override
  String get moduleId => _moduleId;

  @override
  Future<List<SyncItem>> itemsSince(DateTime? since) async => [
        for (final thought in _manager.thoughtsNotifier.value)
          if (since == null || !thought.changedAt.isBefore(since))
            SyncItem(
              itemId: thought.id,
              moduleId: _moduleId,
              deviceId: _deviceId,
              updatedAt: thought.changedAt,
              payload: thought.toJson(),
            ),
      ];

  @override
  Future<void> apply(List<SyncItem> items) async {
    final upserts = <Thought>[];
    final removed = <String, DateTime>{};
    for (final item in items) {
      if (item.isDeleted) {
        removed[item.itemId] = item.updatedAt;
        continue;
      }
      // The envelope's id is authenticated (AAD); the payload's id must agree
      // or the payload is not what the relay claims it is.
      if (item.payload['id'] != item.itemId) continue;
      final Thought thought;
      try {
        thought = Thought.fromJson(item.payload);
      } on Object {
        // A shape this build can't read (a newer version elsewhere): skip it
        // rather than fail the round — a throw keeps the pull watermark where
        // it is, so the same item would fail every round after this one.
        continue;
      }
      upserts.add(thought.copyWith(changedAt: item.updatedAt));
    }
    _manager.applySynced(upserts, removed);
  }
}
