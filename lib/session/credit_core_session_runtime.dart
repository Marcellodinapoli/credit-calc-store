import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../offline/services/session_service.dart';

/// Servizi condivisi CreditCore + sessione unica dispositivo.
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

  /// Avvia subito il claim sessione (in parallelo ad altri controlli di avvio).
  static Future<void> ensureBootstrap(String userId) async {
    if (bootstrapComplete &&
        sessionService != null &&
        sessionService!.userId == userId) {
      return;
    }

    if (sessionService != null && sessionService!.userId != userId) {
      clear();
    }

    bootstrapFuture ??= _runBootstrap(userId);
    try {
      await bootstrapFuture;
    } catch (_) {
      bootstrapFuture = null;
      bootstrapComplete = false;
    }
  }

  static Future<void> _runBootstrap(String userId) async {
    final service = SessionService(userId: userId);
    await service.initialize();
    sessionService = service;
    bootstrapComplete = true;
  }

  static void resetPendingBootstrap() {
    if (bootstrapComplete) return;
    bootstrapFuture = null;
  }

  static Future<void> releaseSession() async {
    await sessionService?.releaseIfHolder();
  }

  static void clear() {
    sessionService?.dispose();
    sessionService = null;
    bootstrapFuture = null;
    bootstrapComplete = false;
  }

  /// Libera la sessione Firestore e poi esce dall'account.
  static Future<void> signOutWithSessionRelease() async {
    await releaseSession();
    clear();
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}
