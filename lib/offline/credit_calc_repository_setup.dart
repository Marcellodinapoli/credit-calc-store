import 'dart:async';

import 'package:credit_calc_core/credit_calc_core.dart';

import 'credit_calc_runtime.dart';
import 'adapters/repository_commission_creditor_data_access.dart';
import 'adapters/repository_commission_entry_data_access.dart';
import 'models/credit_calc_mode.dart';
import 'repository/credit_calc_repository.dart';
import 'services/mode_preferences_service.dart';
import 'services/session_service.dart';
import 'services/sync_engine.dart';

/// Installa / aggiorna il repository dopo scelta o cambio modalità.
abstract final class CreditCalcRepositorySetup {
  static void apply({
    required CreditCalcMode mode,
    required String userId,
    required ModePreferencesService modePrefs,
    required SessionService sessionService,
    required SyncEngine syncEngine,
  }) {
    CreditCalcRepository.install(
      mode: mode,
      userId: userId,
      modePrefs: modePrefs,
      sessionService: sessionService,
      syncEngine: syncEngine,
    );
    CommissionEntryDataAccess.instance =
        RepositoryCommissionEntryDataAccess();
    CommissionCreditorDataAccess.instance =
        RepositoryCommissionCreditorDataAccess();
  }

  static void notifyDataChanged() {
    try {
      CreditCalcRepository.instance.notifyCreditorsChanged();
      CreditCalcRepository.instance.notifyCalculationsChanged();
    } catch (_) {}
    unawaited(CreditCalcRuntime.refreshPendingSyncCount());
  }
}
