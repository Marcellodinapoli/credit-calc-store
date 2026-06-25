import 'package:credit_calc_core/credit_calc_core.dart';

import 'develop_sync_sqlite_store.dart';
import 'models/develop_local_collection.dart';

class DevelopPdrScheduleStorage implements PdrScheduleStorage {
  DevelopPdrScheduleStorage(this._store);

  final DevelopSyncSqliteStore _store;

  @override
  Stream<List<PdrScheduleRecord>> watchSchedules() {
    return _store
        .watchRevision(DevelopLocalCollection.pdrSchedules)
        .asyncMap((_) => listSchedules());
  }

  @override
  Future<List<PdrScheduleRecord>> listSchedules() async {
    final rows =
        await _store.recordsForCollection(DevelopLocalCollection.pdrSchedules);
    return rows
        .map((row) => PdrScheduleRecord.fromStored(row.id, row.payload))
        .toList();
  }

  @override
  Future<PdrScheduleRecord> upsertForPractice({
    required String companyName,
    required String creditorId,
    required String creditorName,
    required String planSource,
    required List<CommissionInstallmentPayment> installments,
  }) async {
    final parsed = PdrScheduleStorage.installmentsFromPayments(installments);
    if (parsed.isEmpty) {
      throw StateError('Nessuna rata nel calendario PDR');
    }

    final docId = PdrScheduleStorage.practiceDocId(creditorId, companyName);
    final existing = await _store.recordById(
      collection: DevelopLocalCollection.pdrSchedules,
      id: docId,
    );
    final now = DateTime.now();
    final createdAt = existing?.createdAt ?? now;

    final payload = {
      'companyName': companyName.trim(),
      'creditorId': creditorId,
      'creditorName': creditorName.trim(),
      'planSource': planSource,
      'installments': parsed.map((i) => i.toJson()).toList(),
      'totalAmount': parsed.fold<double>(0, (sum, i) => sum + i.amount),
      'rateCount': parsed.length,
      'createdAtMs': createdAt.millisecondsSinceEpoch,
      'updatedAtMs': now.millisecondsSinceEpoch,
    };

    await _store.upsertRecord(
      collection: DevelopLocalCollection.pdrSchedules,
      id: docId,
      payload: payload,
      createdAt: createdAt,
    );

    return PdrScheduleRecord(
      id: docId,
      companyName: companyName.trim(),
      creditorId: creditorId,
      creditorName: creditorName.trim(),
      planSource: planSource,
      installments: parsed,
      createdAt: createdAt,
      updatedAt: now,
    );
  }
}
