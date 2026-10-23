import 'package:mars_sync_flutter/mars_sync_flutter.dart';
import 'package:mars_thoughts/util/time_format.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// mars_thoughts is the first device: English, it generates the key.
/// Mars Hub's Sync page shows the same screen with the same texts.
const thoughtsSyncStrings = SyncStrings.english(
  unpairBody: 'Removes the relay pairing and the encryption key from this '
      'device. Thoughts stay where they are, here and on the relay.',
  lastSynced: _lastSynced,
);

String _lastSynced(DateTime at) => 'last sync ${formatThoughtTime(at)}';

/// The module's sync ledger, in this app's prefs. Mars Hub uses it too.
/// No key prefix: the first synced app, its `sync_*` keys predate prefixes.
SyncLedger thoughtsLedger(SharedPreferences prefs) => SyncLedger(prefs);
