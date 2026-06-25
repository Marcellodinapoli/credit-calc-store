import 'package:credit_calc_core/credit_calc_core.dart';

import '../repository/credit_calc_repository.dart';

class RepositoryCommissionEntriesDataAccess
    implements CommissionEntriesDataAccess {
  @override
  Stream<List<CommissionEntryRecord>> watchCommissionEntries() {
    return CreditCalcRepository.instance.watchCalculationRecords().map(
          (records) => CommissionCollectionsHelper.commissionEntries([
            for (final record in records)
              CommissionEntryRecord(id: record.id, data: record.data),
          ]),
        );
  }
}
