import 'dart:async';

import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/foundation.dart';

import 'credit_calc_repository_setup.dart';
import 'develop_sync/develop_sync_coordinator.dart';
import 'local_itinerary_coordinator.dart';
import 'services/session_service.dart';

/// Servizi CreditCalc attivi nella sessione corrente.
abstract final class CreditCalcRuntime {
  static SessionService? sessionService;

  static final ValueNotifier<String?> writeBlockedMessage =
      ValueNotifier<String?>(null);

  static bool get isReady => sessionService != null;

  static void install({required SessionService sessionService}) {
    CreditCalcRuntime.sessionService = sessionService;
  }

  static void notifyWriteBlocked(String message) {
    writeBlockedMessage.value = message;
  }

  static void clear() {
    unawaited(LocalItineraryCoordinator.stop());
    unawaited(DevelopSyncCoordinator.stop());
    sessionService = null;
    writeBlockedMessage.value = null;
  }

  static Future<void> reclaimSessionAfterUnlock() async {
    try {
      PublicPlanLimitsConfigService.start();
      await PublicPlanLimitsConfigService.ensureLoaded(
        timeout: const Duration(seconds: 4),
      );
      CreditCalcRepositorySetup.notifyDataChanged();
    } catch (_) {}
  }
}
