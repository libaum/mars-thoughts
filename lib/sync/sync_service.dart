import 'package:flutter/foundation.dart';
import 'package:mars_sync/mars_sync.dart';
import 'package:mars_thoughts/data/local_storage_service.dart';
import 'package:mars_thoughts/logic/thoughts_manager.dart';
import 'package:mars_thoughts/sync/secure_sync_key_store.dart';
import 'package:mars_thoughts/sync/thoughts_sync_repository.dart';

enum SyncPhase { unpaired, idle, syncing, error }

class SyncStatus {
  final SyncPhase phase;
  final DateTime? lastSyncedAt;
  final String? error;

  const SyncStatus({required this.phase, this.lastSyncedAt, this.error});

  bool get isPaired => phase != SyncPhase.unpaired;
}

/// Owns the personal flavor's sync lifecycle: pairing (server URL, device
/// token, encryption key), the wired-up [MarsSyncEngine], and a single
/// `syncNow()` that the UI and app lifecycle can call freely — overlapping
/// calls collapse into the one already running.
///
/// The three pairing steps are independent so a device can be paired in any
/// order; sync only runs once all of them are in place.
class SyncService {
  final LocalStorageService _storage;
  final ThoughtsManager _manager;
  final SecureSyncKeyStore _keys = SecureSyncKeyStore();

  final statusNotifier = ValueNotifier<SyncStatus>(
    const SyncStatus(phase: SyncPhase.unpaired),
  );

  MarsSyncEngine? _engine;
  Future<void>? _inFlight;

  SyncService({
    required LocalStorageService storage,
    required ThoughtsManager manager,
  })  : _storage = storage,
        _manager = manager;

  Future<void> init() async {
    await _rebuildEngine();
  }

  String? get serverUrl => _storage.getSyncServerUrl();

  Future<String?> get deviceId => _keys.readDeviceId();

  Future<bool> get hasEncryptionKey async =>
      (await _keys.readEncryptionKey()) != null;

  Future<bool> get hasDeviceToken async =>
      (await _keys.readDeviceToken()) != null;

  /// Stores the hub URL and device token, then asks the hub which device id
  /// the token belongs to — the user never retypes the name they registered
  /// on the server. Throws if the hub rejects the token or is unreachable.
  Future<void> pairDevice({required String serverUrl, required String token}) async {
    final trimmedUrl = serverUrl.trim();
    final trimmedToken = token.trim();
    final client = SyncClient(baseUrl: Uri.parse(trimmedUrl), deviceToken: trimmedToken);
    final deviceId = await client.whoami();

    await _storage.setSyncServerUrl(trimmedUrl);
    await _keys.writeDeviceToken(trimmedToken);
    await _keys.writeDeviceId(deviceId);
    await _rebuildEngine();
  }

  /// First device only: mints the shared encryption key. Returns it encoded
  /// for transfer to the other devices — and for backing up, because there
  /// is no way to recover it from the hub.
  Future<String> generateEncryptionKey() async {
    final encryptor = await SyncEncryptor.generate();
    final exported = await encryptor.exportKey();
    await _keys.writeEncryptionKey(exported);
    await _rebuildEngine();
    return exported;
  }

  /// Every other device: takes the key generated elsewhere.
  Future<void> importEncryptionKey(String encoded) async {
    final trimmed = encoded.trim();
    // Fail early on garbage rather than at the first decrypt.
    SyncEncryptor.importKey(trimmed);
    await _keys.writeEncryptionKey(trimmed);
    await _rebuildEngine();
  }

  Future<String?> exportEncryptionKey() => _keys.readEncryptionKey();

  /// Drops pairing and key. The hub keeps its (ciphertext) copy of every
  /// thought; local thoughts stay as they are. The sync watermark resets so a
  /// later re-pair does one full round again.
  Future<void> unpair() async {
    await _keys.clear();
    await _storage.setSyncServerUrl(null);
    await _storage.setSyncLastSyncedAt(null);
    await _rebuildEngine();
  }

  /// Runs one push/pull round. Never throws — outcome lands in
  /// [statusNotifier] — so it's safe to fire from lifecycle callbacks.
  Future<void> syncNow() {
    final running = _inFlight;
    if (running != null) return running;
    final future = _run().whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }

  Future<void> _run() async {
    final engine = _engine;
    if (engine == null) return;
    _publish(SyncPhase.syncing);
    try {
      await engine.syncNow();
      _publish(SyncPhase.idle);
    } catch (e) {
      _publish(SyncPhase.error, error: _describe(e));
    }
  }

  Future<void> _rebuildEngine() async {
    final url = _storage.getSyncServerUrl();
    final token = await _keys.readDeviceToken();
    final key = await _keys.readEncryptionKey();
    final deviceId = await _keys.readDeviceId();

    if (url == null || token == null || key == null || deviceId == null) {
      _engine = null;
      _publish(SyncPhase.unpaired);
      return;
    }

    _engine = MarsSyncEngine(
      repository: ThoughtsSyncRepository(
        manager: _manager,
        storage: _storage,
        deviceId: deviceId,
      ),
      client: SyncClient(baseUrl: Uri.parse(url), deviceToken: token),
      encryptor: SyncEncryptor.importKey(key),
    );
    _publish(SyncPhase.idle);
  }

  void _publish(SyncPhase phase, {String? error}) {
    statusNotifier.value = SyncStatus(
      phase: phase,
      lastSyncedAt: _storage.getSyncLastSyncedAt(),
      error: error,
    );
  }

  String _describe(Object e) {
    if (e is SyncClientException) {
      return switch (e.statusCode) {
        401 => 'Hub rejected this device token',
        429 => 'Hub is rate-limiting this device',
        null => 'Hub unreachable',
        final code => 'Hub error $code',
      };
    }
    if (e is SyncDecryptException) return 'Encryption key mismatch';
    return 'Sync failed';
  }
}
