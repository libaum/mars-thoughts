import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `../mars_hub` (Linux desktop) imports this app's `domain/`, `logic/`,
/// `data/`, `sync/` and `util/` layers as a library. Anything in there that
/// reads the Android build flavor or talks to an Android-only plugin would
/// compile fine on the desktop and silently misbehave at runtime — the
/// flavor constant is simply `null` there, a plugin call throws
/// `MissingPluginException`. So those layers may not touch either; the gates
/// belong in `services/`, `pages/` and `main.dart`, which the hub does not
/// import (except `pages/sync_screen.dart`, which uses only portable APIs).
void main() {
  const sharedDirs = ['lib/domain', 'lib/logic', 'lib/data', 'lib/sync', 'lib/util'];

  // The two files that *define* the boundary are the only ones allowed to
  // mention what's behind it.
  const exempt = {
    'lib/sync/sync_flags.dart': ['appFlavor', 'kSyncEnabled', 'package:flutter/services.dart'],
    'lib/sync/secure_sync_key_store.dart': ['flutter_secure_storage'],
  };

  const forbidden = [
    'sync_flags.dart',
    'kSyncEnabled',
    'appFlavor',
    'flutter_secure_storage',
    'dart:io',
    'package:flutter/services.dart',
  ];

  test('shared layers stay free of Android-only code', () {
    final violations = <String>[];
    for (final dir in sharedDirs) {
      for (final entity in Directory(dir).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path;
        final allowed = exempt[path] ?? const <String>[];
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('///') || line.trimLeft().startsWith('//')) {
            continue;
          }
          for (final token in forbidden) {
            if (line.contains(token) && !allowed.contains(token)) {
              violations.add('$path:${i + 1}: $token');
            }
          }
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
