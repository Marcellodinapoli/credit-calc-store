import 'package:credit_calc_core/credit_calc_core.dart';

import '../repository/credit_calc_repository.dart';

/// Allinea i totali limiti piano su Firebase dopo mutazioni locali.
abstract final class DevelopPublicUsageTotalsSync {
  static Future<void> syncFromLocalStore(String userId) async {
    if (userId.isEmpty) return;

    try {
      final repo = CreditCalcRepository.instance;
      final creditors = await repo.listCreditorRecords();
      var schemas = 0;
      for (final record in creditors) {
        final settings = record.data['commissionSettings'];
        if (settings is Map && settings.isNotEmpty) schemas++;
      }
      await PublicUsageCountsDataAccess.instance.publishTotals(
        userId: userId,
        creditors: creditors.length,
        commissionSchemas: schemas,
      );
    } catch (_) {}
  }
}
