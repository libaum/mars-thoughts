import 'package:flutter/services.dart' show appFlavor;

/// Whether this build carries the personal sync feature.
///
/// Driven purely by the Android product flavor (`--flavor personal`), which
/// is also the only variant whose manifest declares the INTERNET permission.
/// `appFlavor` is a compile-time constant, so in the `store` flavor every
/// `if (kSyncEnabled)` branch is dead code and gets tree-shaken out of the
/// binary — the public app doesn't merely have sync switched off, it doesn't
/// contain it.
const bool kSyncEnabled = appFlavor == 'personal';
