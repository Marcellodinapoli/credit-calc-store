import 'dart:async';

import 'package:flutter/foundation.dart';

import '../offline/services/session_service.dart';

/// Sessione unica CreditCore condivisa tra web, app store e moduli Form/Calc/Job.
abstract final class CreditCoreSessionRuntime {
  static SessionService? sessionService;
  static Future<void>? bootstrapFuture;
  static Timer? _heartbeat;
  static bool bootstrapComplete = false;

  static final ValueNotifier<bool> sessionRevoked = ValueNotifier(false);

  static bool get isSessionReady =>
      bootstrapComplete && sessionService != null && bootstrapFuture != null;

  static Future<void> waitUntilReady() async {
    final pending = bootstrapFuture;
    if (pending != null) await pending;
  }

  static void startHeartbeat(SessionService service) {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(
      const Duration(seconds: 60),
      (_) => service.touchActivity(),
    );
  }

  static void stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  static void handleSessionRevoked() {
    if (sessionRevoked.value) return;
    sessionRevoked.value = true;
    bootstrapFuture = null;
    bootstrapComplete = false;
    stopHeartbeat();
  }

  static void clear() {
    sessionService?.dispose();
    sessionService = null;
    bootstrapFuture = null;
    bootstrapComplete = false;
    sessionRevoked.value = false;
    stopHeartbeat();
  }
}
