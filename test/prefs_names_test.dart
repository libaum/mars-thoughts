// Paired devices store the sync ledger under these names; the pull watermark
// keeps its pre-rename `hub_id` (docs/adr/0001-relay-rename-keeps-hub-id-on-the-wire.md
// at the Mars root). A renamed key would make each device forget where it
// left off. The ledger's own tests pin the names per prefix; this pins ours.
import 'package:flutter_test/flutter_test.dart';
import 'package:mars_thoughts/sync/pairing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('the ledger reads what earlier builds stored', () async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({
      'sync_server_url': 'https://relay.example',
      'sync_last_synced_at': 1000,
      'sync_last_seen_seq': 42,
      'sync_last_seen_hub_id': 'R1',
      'sync_purged': '{"a":1000}',
    });
    final ledger = thoughtsLedger(await SharedPreferences.getInstance());
    expect(ledger.serverUrl, 'https://relay.example');
    expect(ledger.lastSyncedAt, DateTime.fromMillisecondsSinceEpoch(1000));
    expect(ledger.pullWatermark!.seq, 42);
    expect(ledger.pullWatermark!.relayId, 'R1');
    expect(ledger.purged.keys, ['a']);
  });
}
