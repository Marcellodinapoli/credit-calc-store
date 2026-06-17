import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _initialized = false;

bool get isSqfliteDesktopPlatform {
  if (kIsWeb) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.linux ||
    TargetPlatform.macOS =>
      true,
    _ => false,
  };
}

Future<void> ensureSqfliteDesktopInitialized() async {
  if (!isSqfliteDesktopPlatform || _initialized) return;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  _initialized = true;
}
