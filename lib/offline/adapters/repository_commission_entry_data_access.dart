import 'package:credit_calc_core/credit_calc_core.dart';

import '../repository/credit_calc_repository.dart';

/// Commission entry via [CreditCalcRepository] (web e offline).
class RepositoryCommissionEntryDataAccess implements CommissionEntryDataAccess {
  @override
  Future<Map<String, dynamic>?> loadEntry(String entryId) async {
    final record = await CreditCalcRepository.instance.getCalculation(entryId);
    return record?.data;
  }

  @override
  Future<Map<String, dynamic>?> loadCreditorData(String creditorId) async {
    final record = await CreditCalcRepository.instance.getCreditor(creditorId);
    return record?.data;
  }

  @override
  Future<void> saveEntry({
    required Map<String, dynamic> payload,
    String? entryId,
  }) async {
    final data = Map<String, dynamic>.from(payload);
    data.remove('updatedAt');
    data.remove('createdAt');

    final repo = CreditCalcRepository.instance;
    if (entryId != null && entryId.isNotEmpty) {
      await repo.saveCalculation(id: entryId, data: data, isNew: false);
      return;
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await repo.saveCalculation(id: id, data: data, isNew: true);
  }
}
