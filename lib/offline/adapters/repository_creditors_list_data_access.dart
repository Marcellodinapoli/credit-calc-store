import 'package:credit_calc_core/credit_calc_core.dart';

import '../repository/credit_calc_repository.dart';

class RepositoryCreditorsListDataAccess implements CreditorsListDataAccess {
  @override
  Stream<List<CreditorRecord>> watchCreditors() {
    return CreditCalcRepository.instance.watchCreditorRecords().map(
          (records) => [
            for (final record in records)
              CreditorRecord(id: record.id, data: record.data),
          ],
        );
  }

  @override
  String newCreditorId() => CreditCalcRepository.instance.newCreditorId();

  @override
  Future<Map<String, dynamic>?> loadCreditor(String creditorId) async {
    return (await CreditCalcRepository.instance.getCreditor(creditorId))?.data;
  }

  @override
  Future<bool> creditorExists(String creditorId) async {
    return (await CreditCalcRepository.instance.getCreditor(creditorId)) != null;
  }

  @override
  Future<void> saveCreditor({
    required String creditorId,
    required Map<String, dynamic> data,
  }) async {
    final payload = Map<String, dynamic>.from(data)
      ..remove('createdAt')
      ..remove('updatedAt');
    final exists = await creditorExists(creditorId);
    await CreditCalcRepository.instance.saveCreditor(
      id: creditorId,
      data: payload,
      isNew: !exists,
    );
  }

  @override
  Future<void> deleteCreditor(String creditorId) async {
    await CreditCalcRepository.instance.deleteCreditor(creditorId);
  }
}
