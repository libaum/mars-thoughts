import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mars_sync/mars_sync.dart';

/// The pairing secrets, kept in Android Keystore-backed storage rather than
/// SharedPreferences — a plain prefs XML is readable from any backup or root
/// shell, and these two values are the whole ballgame: the token is the
/// device's identity on the hub, the key is what makes every stored thought
/// readable.
class SecureSyncKeyStore implements SyncKeyStore {
  static const _keyDeviceToken = 'sync_device_token';
  static const _keyEncryptionKey = 'sync_encryption_key';
  static const _keyDeviceId = 'sync_device_id';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<String?> readDeviceToken() => _storage.read(key: _keyDeviceToken);

  @override
  Future<void> writeDeviceToken(String token) =>
      _storage.write(key: _keyDeviceToken, value: token);

  @override
  Future<String?> readEncryptionKey() => _storage.read(key: _keyEncryptionKey);

  @override
  Future<void> writeEncryptionKey(String base64Key) =>
      _storage.write(key: _keyEncryptionKey, value: base64Key);

  @override
  Future<String?> readDeviceId() => _storage.read(key: _keyDeviceId);

  @override
  Future<void> writeDeviceId(String deviceId) =>
      _storage.write(key: _keyDeviceId, value: deviceId);

  Future<void> clear() async {
    await _storage.delete(key: _keyDeviceToken);
    await _storage.delete(key: _keyEncryptionKey);
    await _storage.delete(key: _keyDeviceId);
  }
}
