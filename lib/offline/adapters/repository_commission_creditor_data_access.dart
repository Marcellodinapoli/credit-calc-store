import 'package:credit_calc_core/credit_calc_core.dart';

import '../repository/credit_calc_repository.dart';

class RepositoryCommissionCreditorDataAccess
    implements CommissionCreditorDataAccess {
  @override
  Future<List<CreditorPick>> listCreditorsForPicker() async {
    final records = await CreditCalcRepository.instance.listCreditorRecords();
    return [
      for (var i = 0; i < records.length; i++)
        CreditorPick(
          id: records[i].id,
          name: creditorDisplayLabel(i, records[i].data),
        ),
    ];
  }

  @override
  Future<Map<String, dynamic>?> loadCreditor(String creditorId) async {
    final record = await CreditCalcRepository.instance.getCreditor(creditorId);
    return record?.data;
  }

  @override
  Future<void> saveCommissionSettings({
    required String creditorId,
    required Map<String, dynamic> commissionSettings,
  }) async {
    await CreditCalcRepository.instance.saveCreditor(
      id: creditorId,
      data: {'commissionSettings': commissionSettings},
      isNew: false,
    );
  }
}
