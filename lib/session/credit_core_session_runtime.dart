import 'dart:async';

import '../offline/services/session_service.dart';

/// Servizi condivisi CreditCore (senza blocco sessione globale).
abstract final class CreditCoreSessionRuntime {
  static SessionService? sessionService;
  static Future<void>? bootstrapFuture;
  static bool bootstrapComplete = false;

  static bool get isSessionReady =>
      bootstrapComplete && sessionService != null;

  static Future<void> waitUntilReady() async {
    final pending = bootstrapFuture;
    if (pending == null) return;
    try {
      await pending.timeout(const Duration(seconds: 12));
    } on TimeoutException {
      resetPendingBootstrap();
    }
  }

  static void resetPendingBootstrap() {
    if (bootstrapComplete) return;
    bootstrapFuture = null;
  }

  static void clear() {
    sessionService?.dispose();
    sessionService = null;
    bootstrapFuture = null;
    bootstrapComplete = false;
  }
}
