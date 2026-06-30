import 'package:credit_calc_core/credit_calc_core.dart';

import 'adapters/repository_commission_creditor_data_access.dart';
import 'adapters/repository_commission_entries_data_access.dart';
import 'adapters/repository_commission_entry_data_access.dart';
import 'adapters/repository_creditors_list_data_access.dart';
import 'device_public_usage_local_data_access.dart';
import 'repository/credit_calc_repository.dart';

/// Installa il repository dati operativi CreditCalc.
abstract final class CreditCalcRepositorySetup {
  static DevicePublicUsageLocalDataAccess? _localUsage;

  static void apply({required String userId}) {
    CreditCalcRepository.install(userId: userId);
    _localUsage = DevicePublicUsageLocalDataAccess(userId);
    PublicUsageLocalDataAccess.install(_localUsage!);
    CommissionEntryDataAccess.instance =
        RepositoryCommissionEntryDataAccess();
    CommissionCreditorDataAccess.instance =
        RepositoryCommissionCreditorDataAccess();
    CommissionEntriesDataAccess.instance =
        RepositoryCommissionEntriesDataAccess();
    CreditorsListDataAccess.instance = RepositoryCreditorsListDataAccess();
  }

  static void clear() {
    PublicUsageLocalDataAccess.clear();
    _localUsage = null;
  }

  static void notifyDataChanged() {
    try {
      CreditCalcRepository.instance.notifyCreditorsChanged();
      CreditCalcRepository.instance.notifyCalculationsChanged();
      _localUsage?.notifyChanged();
    } catch (_) {}
  }
}
