import 'package:flutter_test/flutter_test.dart';
import 'package:mars_sync/mars_sync.dart';
import 'package:mars_sync_flutter/mars_sync_flutter.dart';
import 'package:mars_thoughts/data/local_storage_service.dart';
import 'package:mars_thoughts/logic/thoughts_manager.dart';
import 'package:mars_thoughts/services/service_locator.dart';
import 'package:mars_thoughts/sync/pairing.dart';
import 'package:mars_thoughts/sync/thoughts_sync_items.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The relay's write rule, reduced to what these tests need.
class _Relay {
  final rows = <String, SyncItem>{};
  var _seq = 0;

  void push(List<SyncItem> items) {
    for (final item in items) {
      final key = '${item.moduleId}/${item.itemId}';
      final stored = rows[key];
      if (stored == null || item.updatedAtMs >= stored.updatedAtMs) {
        rows[key] = item.copyWith(seq: ++_seq);
      }
    }
  }

  PullResult pull(String module, int sinceSeq) {
    final page = rows.values
        .where((r) => r.moduleId == module && r.seq! > sinceSeq)
        .toList()
      ..sort((a, b) => a.seq!.compareTo(b.seq!));
    return PullResult(
      items: page,
      latestSeq: page.isEmpty ? sinceSeq : page.last.seq!,
      relayId: 'relay',
      hasMore: false,
    );
  }

  bool holdsThoughts() => rows.keys.any((k) => k.startsWith('mars_thoughts/'));
}

class _Transport implements SyncTransport {
  final _Relay relay;
  final String deviceId;
  _Transport(this.relay, this.deviceId);

  @override
  Future<String> whoami() async => deviceId;

  @override
  Future<void> push(String moduleId, List<SyncItem> items) async => relay.push(items);

  @override
  Future<PullResult> pull(String moduleId, {required int sinceSeq}) async =>
      relay.pull(moduleId, sinceSeq);
}

class _Keys implements SyncKeyStore {
  final _values = <String, String>{};
  @override
  Future<void> clear() async => _values.clear();
  @override
  Future<String?> readDeviceId() async => _values['id'];
  @override
  Future<String?> readDeviceToken() async => _values['token'];
  @override
  Future<String?> readEncryptionKey() async => _values['key'];
  @override
  Future<void> writeDeviceId(String deviceId) async => _values['id'] = deviceId;
  @override
  Future<void> writeDeviceToken(String token) async => _values['token'] = token;
  @override
  Future<void> writeEncryptionKey(String base64Key) async => _values['key'] = base64Key;
}

/// mars_thoughts' wiring of the shared SyncService. The service's own
/// guarantees — the key check before the first push, the generation guard
/// against re-pairs mid-check, overlapping rounds — are pinned in
/// mars_sync_flutter's tests; these check that thoughts get them.
void main() {
  late _Relay relayA;
  late _Relay relayB;
  late String keyA;
  late SyncLedger ledger;
  late ThoughtsManager manager;
  late _Keys keys;

  setUp(() async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    getIt.registerSingleton<LocalStorageService>(await LocalStorageService.getInstance());
    ledger = thoughtsLedger(await SharedPreferences.getInstance());
    manager = ThoughtsManager(onPurged: ledger.recordPurged);
    keys = _Keys();

    relayA = _Relay();
    relayB = _Relay();
    final a = await SyncEncryptor.generate();
    keyA = await a.exportKey();
    // Each relay already knows its own key (registered by some first device).
    await KeyCheck(client: _Transport(relayA, 'first'), encryptor: a, deviceId: 'first').run();
    final b = await SyncEncryptor.generate();
    await KeyCheck(client: _Transport(relayB, 'first'), encryptor: b, deviceId: 'first').run();
  });

  SyncService thoughtsSync() => SyncService.module(
        ledger: ledger,
        keys: keys,
        items: (deviceId) => ThoughtsSyncItems(manager: manager, deviceId: deviceId),
        strings: thoughtsSyncStrings,
        transport: (uri, token) => _Transport(uri.host == 'a' ? relayA : relayB, 'phone'),
      );

  test('a paired phone pushes its thoughts, and unpair resets both watermarks', () async {
    final sync = thoughtsSync();
    await sync.init();
    await sync.pairDevice(serverUrl: 'https://a', token: 't');
    await sync.importEncryptionKey(keyA);
    manager.create('geheim');
    await sync.syncNow();

    expect(sync.statusNotifier.value.phase, SyncPhase.idle);
    expect(relayA.holdsThoughts(), isTrue);
    expect(ledger.lastSyncedAt, isNotNull);
    expect(ledger.pullWatermark, isNotNull);

    await sync.unpair();
    expect(ledger.serverUrl, isNull);
    expect(ledger.lastSyncedAt, isNull);
    expect(ledger.pullWatermark, isNull);
    expect(sync.statusNotifier.value.phase, SyncPhase.unpaired);
  });

  test('reload() makes the next round prove the key against the new relay', () async {
    // New for thoughts with the shared service: Mars Hub's leader could
    // re-pair the shared state under it, too.
    final sync = thoughtsSync();
    await sync.init();
    await sync.pairDevice(serverUrl: 'https://a', token: 't');
    await sync.importEncryptionKey(keyA);
    manager.create('geheim');
    await sync.syncNow();
    expect(relayA.holdsThoughts(), isTrue);

    await ledger.setServerUrl('https://b');
    await sync.reload();
    await sync.syncNow();

    expect(sync.statusNotifier.value.phase, SyncPhase.error);
    expect(sync.statusNotifier.value.error, 'Encryption key does not match the relay');
    expect(relayB.holdsThoughts(), isFalse, reason: 'pushed with a key relay B never saw');
  });
}
