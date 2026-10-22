import 'package:mars_sync_flutter/mars_sync_flutter.dart';
import 'package:mars_thoughts/data/local_storage_service.dart';
import 'package:mars_thoughts/util/time_format.dart';

/// mars_thoughts is the first device: English, it generates the key.
/// Mars Hub's Sync page shows the same screen with the same texts.
const thoughtsSyncStrings = SyncStrings.english(
  unpairBody: 'Removes the relay pairing and the encryption key from this '
      'device. Thoughts stay where they are, here and on the relay.',
  lastSynced: _lastSynced,
);

String _lastSynced(DateTime at) => 'last sync ${formatThoughtTime(at)}';

/// The pairing's non-secret half, in this app's prefs. Mars Hub uses it too.
class ThoughtsPairingPrefs implements PairingPrefs {
  final LocalStorageService _storage;

  ThoughtsPairingPrefs(this._storage);

  @override
  String? get serverUrl => _storage.getSyncServerUrl();

  @override
  Future<void> setServerUrl(String? url) => _storage.setSyncServerUrl(url);

  @override
  DateTime? get lastSyncedAt => _storage.getSyncLastSyncedAt();

  @override
  Future<void> setLastSyncedAt(DateTime? at) => _storage.setSyncLastSyncedAt(at);

  @override
  Future<void> clearPullWatermark() =>
      _storage.setSyncPullWatermark(seq: null, relayId: null);

  /// Nothing here decides on the pairing synchronously at start.
  @override
  Future<void> setPaired(bool paired) async {}
}
