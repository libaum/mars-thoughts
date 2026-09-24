import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mars_sync/mars_sync.dart';
import 'package:mars_thoughts/data/local_storage_service.dart';
import 'package:mars_thoughts/logic/thoughts_manager.dart';
import 'package:mars_thoughts/services/service_locator.dart';
import 'package:mars_thoughts/sync/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The hub's write rule, reduced to what these tests need.
class _Hub {
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
      hubId: 'hub',
      hasMore: false,
    );
  }

  bool holdsThoughts() => rows.keys.any((k) => k.startsWith('mars_thoughts/'));
}

/// Holds key-check pulls until [gate] opens, if one is set.
class _Transport implements SyncTransport {
  final _Hub hub;
  final String deviceId;
  final Completer<void>? gate;
  _Transport(this.hub, this.deviceId, [this.gate]);

  @override
  Future<String> whoami() async => deviceId;

  @override
  Future<void> push(String moduleId, List<SyncItem> items) async => hub.push(items);

  @override
  Future<PullResult> pull(String moduleId, {required int sinceSeq}) async {
    if (moduleId == KeyCheck.moduleId) await gate?.future;
    return hub.pull(moduleId, sinceSeq);
  }
}

class _Keys implements SyncKeyStore {
  final _values = <String, String>{};
  Completer<void>? keyWriteGate;
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
  Future<void> writeEncryptionKey(String base64Key) async {
    await keyWriteGate?.future;
    _values['key'] = base64Key;
  }
}

/// A key check that outlives a re-pair answers a question about the old hub.
/// Its "ok" must not let the device push to the new one unchecked.
void main() {
  late _Hub hubA;
  late _Hub hubB;
  late String keyA;
  late LocalStorageService storage;
  late ThoughtsManager manager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    storage = await LocalStorageService.getInstance();
    getIt.registerSingleton<LocalStorageService>(storage);
    manager = ThoughtsManager(recordPurges: true);

    hubA = _Hub();
    hubB = _Hub();
    final a = await SyncEncryptor.generate();
    keyA = await a.exportKey();
    // Each hub already knows its own key (registered by some first device).
    await KeyCheck(client: _Transport(hubA, 'first'), encryptor: a, deviceId: 'first').run();
    final b = await SyncEncryptor.generate();
    await KeyCheck(client: _Transport(hubB, 'first'), encryptor: b, deviceId: 'first').run();
  });

  test('a key check in a round that outlives a re-pair does not count', () async {
    final gate = Completer<void>();
    final keys = _Keys();
    final sync = SyncService(
      storage: storage,
      manager: manager,
      keys: keys,
      transport: (uri, token) =>
          uri.host == 'a' ? _Transport(hubA, 'phone', gate) : _Transport(hubB, 'phone'),
    );
    await storage.setSyncServerUrl('https://a');
    await keys.writeDeviceToken('t');
    await keys.writeDeviceId('phone');
    await keys.writeEncryptionKey(keyA);
    await sync.init();
    manager.create('geheim');

    final round = sync.syncNow(); // key check against A, held at the gate
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sync.pairDevice(serverUrl: 'https://b', token: 't');
    gate.complete();
    await round;

    await sync.syncNow();
    expect(sync.statusNotifier.value.phase, SyncPhase.error);
    expect(hubB.holdsThoughts(), isFalse, reason: 'pushed with a key hub B never saw');
  });

  test('a key import that outlives a re-pair does not count', () async {
    final keys = _Keys();
    final sync = SyncService(
      storage: storage,
      manager: manager,
      keys: keys,
      transport: (uri, token) => _Transport(uri.host == 'a' ? hubA : hubB, 'phone'),
    );
    await storage.setSyncServerUrl('https://a');
    await keys.writeDeviceToken('t');
    await keys.writeDeviceId('phone');
    await sync.init();
    manager.create('geheim');

    keys.keyWriteGate = Completer<void>();
    final import = sync.importEncryptionKey(keyA); // checked against A
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final repair = sync.pairDevice(serverUrl: 'https://b', token: 't');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    keys.keyWriteGate!.complete();
    await import;
    await repair;

    await sync.syncNow();
    expect(hubB.holdsThoughts(), isFalse, reason: 'pushed with a key hub B never saw');
  });
}
