import 'dart:async';

import 'package:flutter/foundation.dart';

import 'credit_calc_repository_setup.dart';
import 'repository/credit_calc_repository.dart';
import 'services/connectivity_service.dart';
import 'services/mode_preferences_service.dart';
import 'services/realtime_sync_service.dart';
import 'services/session_service.dart';
import 'services/sync_engine.dart';

/// Servizi CreditCalc attivi nella sessione corrente (per impostazioni e menu).
abstract final class CreditCalcRuntime {
  static ModePreferencesService? modePrefs;
  static SessionService? sessionService;
  static SyncEngine? syncEngine;
  static RealtimeSyncService? realtimeSync;

  static final ValueNotifier<String?> writeBlockedMessage =
      ValueNotifier<String?>(null);

  static final ValueNotifier<int> pendingSyncCount = ValueNotifier(0);

  static bool get isReady =>
      modePrefs != null && sessionService != null && syncEngine != null;

  static void install({
    required ModePreferencesService modePrefs,
    required SessionService sessionService,
    required SyncEngine syncEngine,
    RealtimeSyncService? realtimeSync,
  }) {
    CreditCalcRuntime.modePrefs = modePrefs;
    CreditCalcRuntime.sessionService = sessionService;
    CreditCalcRuntime.syncEngine = syncEngine;
    CreditCalcRuntime.realtimeSync = realtimeSync;
  }

  static void notifyWriteBlocked(String message) {
    writeBlockedMessage.value = message;
  }

  static Future<void> refreshPendingSyncCount() async {
    try {
      pendingSyncCount.value =
          await CreditCalcRepository.instance.pendingCount();
    } catch (_) {
      pendingSyncCount.value = 0;
    }
  }

  static void clear() {
    realtimeSync?.dispose();
    realtimeSync = null;
    modePrefs = null;
    sessionService = null;
    syncEngine = null;
    writeBlockedMessage.value = null;
    pendingSyncCount.value = 0;
  }

  static Future<void> reclaimSessionAfterUnlock() async {
    try {
      await sessionService?.ensureLocalSession();
      if (await ConnectivityService.isOnline()) {
        final result = await syncEngine?.runSync();
        if (result?.success == true) {
          CreditCalcRepositorySetup.notifyDataChanged();
        }
      }
      await refreshPendingSyncCount();
    } catch (_) {}
  }
}
