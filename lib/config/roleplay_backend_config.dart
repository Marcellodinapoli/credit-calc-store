import 'package:flutter/foundation.dart' show kIsWeb;

import 'roleplay_backend_config_stub.dart'
    if (dart.library.html) 'roleplay_backend_config_web.dart';

/// Endpoint proxy Realtime su `ai.creditcore.it`.
abstract final class RoleplayBackendConfig {
  static const String secureHost = 'ai.creditcore.it';
  static const String localWsHost = '127.0.0.1';
  static const int localRealtimeWsPort = 3002;

  static String get realtimeWebSocketUrl => resolveRealtimeWebSocketUrl(
        kIsWeb: kIsWeb,
        localWsHost: localWsHost,
        localRealtimeWsPort: localRealtimeWsPort,
        secureHost: secureHost,
      );
}
