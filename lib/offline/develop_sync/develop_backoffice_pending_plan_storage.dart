import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart';

import 'develop_backoffice_pending_plan_repository.dart';

class DevelopBackofficePendingPlanStorage implements BackofficePendingPlanStorage {
  DevelopBackofficePendingPlanStorage(this._repository);

  final DevelopBackofficePendingPlanRepository _repository;

  @override
  Stream<List<BackofficePendingPlan>> watchAll() => _repository.watchAll();

  @override
  Future<BackofficePendingSaveResult> save({
    String? existingId,
    required BackofficePendingPlanType type,
    required String creditorId,
    required String creditorName,
    required Map<String, dynamic> formData,
    required List<BackofficeSummaryRow> summaryRows,
    List<String> commissionDocIds = const [],
    String? companyName,
  }) async {
    try {
      final isNew = existingId == null || existingId.isEmpty;
      final id = isNew
          ? DateTime.now().microsecondsSinceEpoch.toString()
          : existingId;
      final now = DateTime.now();

      final payload = {
        'type': type.storageKey,
        'creditorId': creditorId,
        'creditorName': creditorName,
        'formData': formData,
        'summaryRows': summaryRows.map((row) => row.toMap()).toList(),
        'commissionDocIds': commissionDocIds,
        if (companyName != null && companyName.trim().isNotEmpty)
          'companyName': companyName.trim(),
        if (!isNew) 'modifiedAt': Timestamp.fromDate(now),
      };

      await _repository.savePlan(id: id, data: payload, isNew: isNew);
      return BackofficePendingSaveResult(id: id);
    } catch (error) {
      return BackofficePendingSaveResult(
        errorMessage: 'Errore durante il salvataggio: $error',
      );
    }
  }

  @override
  Future<void> delete(String id) => _repository.delete(id);

  @override
  Future<void> updateCommissionDocIds(String id, List<String> docIds) async {
    final existing = await _repository.getById(id);
    if (existing == null) return;
    final now = DateTime.now();
    await _repository.savePlan(
      id: id,
      data: {
        'commissionDocIds': docIds,
        'acceptedAt': Timestamp.fromDate(now),
        'acceptedVia': BackofficeAcceptedVia.commission.storageKey,
      },
      isNew: false,
    );
  }

  @override
  Future<void> markAcceptedManual(String id) async {
    final existing = await _repository.getById(id);
    if (existing == null) return;
    final now = DateTime.now();
    await _repository.savePlan(
      id: id,
      data: {
        'acceptedAt': Timestamp.fromDate(now),
        'acceptedVia': BackofficeAcceptedVia.manual.storageKey,
      },
      isNew: false,
    );
  }
}
