import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:mars_thoughts/data/local_storage_service.dart';
import 'package:mars_thoughts/data/showcase_data_source.dart';
import 'package:mars_thoughts/logic/thoughts_manager.dart';
import 'package:mars_thoughts/sync/pairing.dart';
import 'package:mars_thoughts/sync/sync_flags.dart';
import 'package:mars_thoughts/sync/thoughts_sync_items.dart';
import 'package:mars_thoughts/theme/theme_manager.dart';
import 'package:mars_sync_flutter/mars_sync_flutter.dart';
import 'package:mars_sync_flutter/secure_sync_key_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Storage must be first (async init)
  final storage = await LocalStorageService.getInstance();
  getIt.registerSingleton<LocalStorageService>(storage);

  // Screenshot-only seed data: every *store* debug build starts with it,
  // never the personal flavor (the fake thoughts would sync to the relay).
  // Only seeds once per install, not on every relaunch, or manual edits made
  // while testing would get wiped out each time the app restarts.
  if (kDebugMode && !kSyncEnabled && !storage.getShowcaseSeeded()) {
    await storage.setThoughts(ShowcaseDataSource.build());
    await storage.setShowcaseSeeded();
  }

  getIt.registerSingleton<ThemeManager>(ThemeManager());

  // Personal flavor only — compiled out of the store flavor entirely.
  final ledger =
      kSyncEnabled ? thoughtsLedger(await SharedPreferences.getInstance()) : null;
  final manager = ThoughtsManager(onPurged: ledger?.recordPurged);
  getIt.registerSingleton<ThoughtsManager>(manager);

  if (kSyncEnabled) {
    final sync = SyncService.module(
      ledger: ledger!,
      // Where the installed app's secrets are — changing the options loses them.
      keys: SecureSyncKeyStore(const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      )),
      items: (deviceId) => ThoughtsSyncItems(manager: manager, deviceId: deviceId),
      strings: thoughtsSyncStrings,
    );
    await sync.init();
    getIt.registerSingleton<SyncService>(sync);
  }
}
