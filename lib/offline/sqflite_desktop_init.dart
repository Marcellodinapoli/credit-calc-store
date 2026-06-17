import 'sqflite_desktop_init_stub.dart'
    if (dart.library.io) 'sqflite_desktop_init_io.dart' as impl;

/// Inizializza SQLite FFI su Windows/macOS/Linux prima di [openDatabase].
Future<void> ensureSqfliteDesktopInitialized() => impl.ensureSqfliteDesktopInitialized();

bool get isSqfliteDesktopPlatform => impl.isSqfliteDesktopPlatform;
