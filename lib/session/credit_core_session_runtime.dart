import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../offline/credit_calc_runtime.dart';
import '../offline/services/session_service.dart';
import '../services/creditcalc_gestionale_service.dart';

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
    try {
      await releaseSession().timeout(const Duration(seconds: 4));
    } catch (_) {}

    clear();
    CreditCalcRuntime.clear();
    try {
      await CreditCalcGestionaleService.instance.clearSession();
    } catch (_) {}

    try {
      // Offline / aereo: signOut Firebase può restare in attesa senza timeout.
      await FirebaseAuth.instance
          .signOut()
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  /// Come [signOutWithSessionRelease], poi chiude Form/Job/Area e ogni pagina
  /// sopra la root (altrimenti si resta su Assistenza, Notifiche, ecc.).
  static Future<void> signOutAndClearNavigation(BuildContext context) async {
    await signOutWithSessionRelease();
    if (!context.mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.popUntil((route) => route.isFirst);
  }
}
