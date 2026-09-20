import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:get_it/get_it.dart';
import 'package:mars_thoughts/data/local_storage_service.dart';
import 'package:mars_thoughts/data/showcase_data_source.dart';
import 'package:mars_thoughts/logic/thoughts_manager.dart';
import 'package:mars_thoughts/sync/sync_flags.dart';
import 'package:mars_thoughts/sync/sync_service.dart';
import 'package:mars_thoughts/theme/theme_manager.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Storage must be first (async init)
  final storage = await LocalStorageService.getInstance();
  getIt.registerSingleton<LocalStorageService>(storage);

  // Screenshot-only seed data: every *store* debug build starts with it,
  // never the personal flavor (the fake thoughts would sync to the hub).
  // Only seeds once per install, not on every relaunch, or manual edits made
  // while testing would get wiped out each time the app restarts.
  if (kDebugMode && !kSyncEnabled && !storage.getShowcaseSeeded()) {
    await storage.setThoughts(ShowcaseDataSource.build());
    await storage.setShowcaseSeeded();
  }

  getIt.registerSingleton<ThemeManager>(ThemeManager());
  final manager = ThoughtsManager(recordPurges: kSyncEnabled);
  getIt.registerSingleton<ThoughtsManager>(manager);

  // Personal flavor only — compiled out of the store flavor entirely.
  if (kSyncEnabled) {
    final sync = SyncService(storage: storage, manager: manager);
    await sync.init();
    getIt.registerSingleton<SyncService>(sync);
  }
}
