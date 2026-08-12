import 'package:get_it/get_it.dart';
import 'package:mars_thoughts/data/local_storage_service.dart';
import 'package:mars_thoughts/data/showcase_data_source.dart';
import 'package:mars_thoughts/logic/thoughts_manager.dart';
import 'package:mars_thoughts/theme/theme_manager.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Storage must be first (async init)
  final storage = await LocalStorageService.getInstance();
  getIt.registerSingleton<LocalStorageService>(storage);

  // Screenshot-only seed data — see ShowcaseDataSource.enabled for the gate.
  if (ShowcaseDataSource.enabled) {
    await storage.setThoughts(ShowcaseDataSource.build());
  }

  getIt.registerSingleton<ThemeManager>(ThemeManager());
  getIt.registerSingleton<ThoughtsManager>(ThoughtsManager());
}
