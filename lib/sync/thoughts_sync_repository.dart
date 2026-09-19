import 'package:mars_sync/mars_sync.dart';
import 'package:mars_thoughts/data/local_storage_service.dart';
import 'package:mars_thoughts/domain/thought.dart';
import 'package:mars_thoughts/logic/thoughts_manager.dart';

/// Maps the app's thoughts onto mars_sync's generic [SyncItem]s.
///
/// The whole [Thought] (including its trash state) rides along as the
/// payload, ordered by `changedAt`. A *purge* — permanent removal from the
/// trash — is the only thing that becomes a tombstone; moving to the trash is
/// just an ordinary edit, so it syncs like one and is restorable everywhere.
class ThoughtsSyncRepository implements SyncRepository {
  static const _moduleId = 'mars_thoughts';

  final ThoughtsManager _manager;
  final LocalStorageService _storage;
  final String _deviceId;

  ThoughtsSyncRepository({
    required ThoughtsManager manager,
    required LocalStorageService storage,
    required String deviceId,
  })  : _manager = manager,
        _storage = storage,
        _deviceId = deviceId;

  @override
  String get moduleId => _moduleId;

  @override
  Future<List<SyncItem>> localChangesSince(DateTime? since) async {
    final items = <SyncItem>[];

    for (final thought in _manager.thoughtsNotifier.value) {
      if (since != null && thought.changedAt.isBefore(since)) continue;
      items.add(
        SyncItem(
          itemId: thought.id,
          moduleId: _moduleId,
          deviceId: _deviceId,
          updatedAt: thought.changedAt,
          payload: thought.toJson(),
        ),
      );
    }

    for (final entry in _storage.getSyncPurged().entries) {
      if (since != null && entry.value.isBefore(since)) continue;
      items.add(
        SyncItem(
          itemId: entry.key,
          moduleId: _moduleId,
          deviceId: _deviceId,
          updatedAt: entry.value,
          deletedAt: entry.value,
          payload: const {},
        ),
      );
    }

    return items;
  }

  @override
  Future<void> applyRemoteItems(List<SyncItem> items) async {
    final upserts = <Thought>[];
    final removed = <String>{};
    for (final item in items) {
      if (item.isDeleted) {
        removed.add(item.itemId);
      } else {
        upserts.add(Thought.fromJson(item.payload));
      }
    }
    _manager.applySynced(upserts, removed);
  }

  @override
  Future<DateTime?> lastSyncedAt() async => _storage.getSyncLastSyncedAt();

  @override
  Future<void> setLastSyncedAt(DateTime time) async {
    await _storage.setSyncLastSyncedAt(time);
    // Everything purged before this watermark has been pushed — forget it.
    // Entries sharing its exact millisecond go once more next round.
    final purged = _storage.getSyncPurged()
      ..removeWhere((_, at) => at.isBefore(time));
    await _storage.setSyncPurged(purged);
  }
}
