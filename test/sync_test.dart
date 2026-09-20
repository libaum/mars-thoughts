import 'package:flutter_test/flutter_test.dart';
import 'package:mars_sync/mars_sync.dart';
import 'package:mars_thoughts/data/local_storage_service.dart';
import 'package:mars_thoughts/domain/thought.dart';
import 'package:mars_thoughts/logic/thoughts_manager.dart';
import 'package:mars_thoughts/services/service_locator.dart';
import 'package:mars_thoughts/sync/thoughts_sync_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Thought.changedAt', () {
    test('defaults to updatedAt when not given', () {
      final t = Thought(
        id: '1',
        text: 'x',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );
      expect(t.changedAt, DateTime(2026, 1, 2));
    });

    test('legacy JSON without changedAt falls back to updatedAt', () {
      final t = Thought.fromJson({
        'id': '1',
        'text': 'x',
        'createdAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'updatedAt': DateTime(2026, 1, 2).millisecondsSinceEpoch,
      });
      expect(t.changedAt, DateTime(2026, 1, 2));
    });

    test('round-trips through JSON independently of updatedAt', () {
      final t = Thought(
        id: '1',
        text: 'x',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        changedAt: DateTime(2026, 1, 5),
      );
      final back = Thought.fromJson(t.toJson());
      expect(back.updatedAt, DateTime(2026, 1, 2));
      expect(back.changedAt, DateTime(2026, 1, 5));
    });
  });

  group('ThoughtsManager sync clock', () {
    late ThoughtsManager manager;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await getIt.reset();
      getIt.registerSingleton<LocalStorageService>(
        await LocalStorageService.getInstance(),
      );
      manager = ThoughtsManager(recordPurges: true);
    });

    test('pinning bumps changedAt but leaves updatedAt alone', () async {
      final created = manager.create('hello')!;
      await Future<void>.delayed(const Duration(milliseconds: 2));
      manager.togglePin(created.id);

      final pinned = manager.thoughtsNotifier.value.single;
      expect(pinned.updatedAt, created.updatedAt);
      expect(pinned.changedAt.isAfter(created.changedAt), isTrue);
    });

    test('trashing and restoring both bump changedAt', () async {
      final created = manager.create('hello')!;
      await Future<void>.delayed(const Duration(milliseconds: 2));
      manager.delete(created.id);
      final trashed = manager.thoughtsNotifier.value.single;
      expect(trashed.changedAt.isAfter(created.changedAt), isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 2));
      manager.restore(created.id);
      final restored = manager.thoughtsNotifier.value.single;
      expect(restored.changedAt.isAfter(trashed.changedAt), isTrue);
      expect(restored.isDeleted, isFalse);
    });

    test('applySynced upserts and removes without touching timestamps', () {
      final local = manager.create('local')!;
      final remote = Thought(
        id: 'remote-1',
        text: 'from laptop',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        changedAt: DateTime(2026, 1, 3),
      );

      manager.applySynced([remote], {local.id: DateTime.now()});

      final all = manager.thoughtsNotifier.value;
      expect(all.map((t) => t.id), ['remote-1']);
      expect(all.single.changedAt, DateTime(2026, 1, 3));
    });

    test('applySynced leaves a locally newer thought alone (edit during round)', () {
      final local = manager.create('typed while syncing')!;
      final stale = Thought(
        id: local.id,
        text: 'older remote',
        createdAt: local.createdAt,
        updatedAt: local.updatedAt,
        changedAt: local.changedAt.subtract(const Duration(seconds: 5)),
      );

      manager.applySynced([stale], {});
      expect(manager.thoughtsNotifier.value.single.text, 'typed while syncing');

      // A tombstone older than the local change is ignored too.
      manager.applySynced([], {local.id: local.changedAt.subtract(const Duration(seconds: 1))});
      expect(manager.thoughtsNotifier.value, hasLength(1));

      // But a newer tombstone wins.
      manager.applySynced([], {local.id: local.changedAt.add(const Duration(seconds: 1))});
      expect(manager.thoughtsNotifier.value, isEmpty);
    });
  });

  group('ThoughtsSyncRepository', () {
    late LocalStorageService storage;
    late ThoughtsManager manager;
    late ThoughtsSyncRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await getIt.reset();
      storage = await LocalStorageService.getInstance();
      getIt.registerSingleton<LocalStorageService>(storage);
      manager = ThoughtsManager(recordPurges: true);
      repo = ThoughtsSyncRepository(
        manager: manager,
        storage: storage,
        deviceId: 'phone',
      );
    });

    test('maps thoughts to items ordered by changedAt, with full payload', () async {
      final t = manager.create('hello')!;

      final items = await repo.localChangesSince(null);

      expect(items, hasLength(1));
      final item = items.single;
      expect(item.itemId, t.id);
      expect(item.moduleId, 'mars_thoughts');
      expect(item.deviceId, 'phone');
      expect(item.updatedAt, t.changedAt);
      expect(item.isDeleted, isFalse);
      expect(Thought.fromJson(item.payload).text, 'hello');
    });

    test('since filter is inclusive of the watermark', () async {
      final t = manager.create('hello')!;

      expect(await repo.localChangesSince(t.changedAt), hasLength(1));
      expect(
        await repo.localChangesSince(
          t.changedAt.add(const Duration(milliseconds: 1)),
        ),
        isEmpty,
      );
    });

    test('trashing is an ordinary edit, purging is a tombstone', () async {
      final t = manager.create('hello')!;
      manager.delete(t.id);

      var items = await repo.localChangesSince(null);
      expect(items.single.isDeleted, isFalse);
      expect(Thought.fromJson(items.single.payload).isDeleted, isTrue);

      manager.purge(t.id);

      items = await repo.localChangesSince(null);
      expect(items.single.itemId, t.id);
      expect(items.single.isDeleted, isTrue);
      expect(items.single.payload, isEmpty);
    });

    test('applyRemoteItems upserts payloads and drops tombstoned ids', () async {
      final doomed = manager.create('doomed')!;
      final incoming = Thought(
        id: 'r1',
        text: 'remote',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        changedAt: DateTime(2026, 1, 1),
      );

      await repo.applyRemoteItems([
        SyncItem(
          itemId: 'r1',
          moduleId: 'mars_thoughts',
          deviceId: 'laptop',
          updatedAt: incoming.changedAt,
          payload: incoming.toJson(),
        ),
        SyncItem(
          itemId: doomed.id,
          moduleId: 'mars_thoughts',
          deviceId: 'laptop',
          updatedAt: DateTime.now(),
          deletedAt: DateTime.now(),
          payload: const {},
        ),
      ]);

      expect(manager.thoughtsNotifier.value.map((t) => t.id), ['r1']);
    });

    test('applyRemoteItems ignores a payload whose id disagrees with the envelope', () async {
      final smuggled = Thought(
        id: 'other',
        text: 'relabelled',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      await repo.applyRemoteItems([
        SyncItem(
          itemId: 'r1',
          moduleId: 'mars_thoughts',
          deviceId: 'laptop',
          updatedAt: DateTime(2026, 1, 1),
          payload: smuggled.toJson(),
        ),
      ]);
      expect(manager.thoughtsNotifier.value, isEmpty);
    });

    test('pull watermark (hub id + seq) is stored separately from the push watermark', () async {
      expect(await repo.pullWatermark(), isNull);
      await repo.setPullWatermark(const PullWatermark(hubId: 'hub-A', seq: 42));
      final stored = await repo.pullWatermark();
      expect(stored!.hubId, 'hub-A');
      expect(stored.seq, 42);
      expect(await repo.lastSyncedAt(), isNull);
    });

    test('applySynced treats an identical echo as a no-op', () {
      final local = manager.create('hello')!;
      var notifications = 0;
      manager.thoughtsNotifier.addListener(() => notifications++);

      manager.applySynced([Thought.fromJson(local.toJson())], {});
      expect(notifications, 0);

      manager.applySynced([local.copyWith(text: 'changed')], {});
      expect(notifications, 1);
      expect(manager.thoughtsNotifier.value.single.text, 'changed');
    });

    test('setLastSyncedAt stores the watermark and prunes pushed purges', () async {
      final t = manager.create('hello')!;
      manager.delete(t.id);
      manager.purge(t.id);
      final purgedAt = storage.getSyncPurged()[t.id]!;

      await repo.setLastSyncedAt(purgedAt.add(const Duration(seconds: 1)));

      expect(await repo.lastSyncedAt(), purgedAt.add(const Duration(seconds: 1)));
      expect(storage.getSyncPurged(), isEmpty);
    });
  });
}
