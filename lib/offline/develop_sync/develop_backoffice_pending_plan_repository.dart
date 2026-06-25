import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart';

import 'develop_sync_sqlite_store.dart';
import 'models/develop_local_collection.dart';

class DevelopBackofficePendingPlanRepository {
  DevelopBackofficePendingPlanRepository(this._store);

  final DevelopSyncSqliteStore _store;

  Stream<List<BackofficePendingPlan>> watchAll() {
    return _store
        .watchRevision(DevelopLocalCollection.backofficePendingPlans)
        .asyncMap((_) => listAll());
  }

  Future<List<BackofficePendingPlan>> listAll() async {
    final rows = await _store.recordsForCollection(
      DevelopLocalCollection.backofficePendingPlans,
    );
    final plans = rows
        .map((row) => BackofficePendingPlan.fromStored(row.id, row.payload))
        .toList();
    plans.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return plans;
  }

  Future<BackofficePendingPlan?> getById(String id) async {
    final row = await _store.recordById(
      collection: DevelopLocalCollection.backofficePendingPlans,
      id: id,
    );
    if (row == null) return null;
    return BackofficePendingPlan.fromStored(row.id, row.payload);
  }

  Future<String> savePlan({
    required String id,
    required Map<String, dynamic> data,
    bool isNew = false,
  }) async {
    var merged = Map<String, dynamic>.from(data);
    if (!isNew) {
      final existing = await getById(id);
      if (existing != null) {
        merged = {...existing.toStoredMap(), ...data};
      }
    }

    final now = DateTime.now();
    if (isNew || merged['submittedAt'] == null) {
      merged['submittedAt'] = Timestamp.fromDate(now);
    }
    merged['updatedAt'] = Timestamp.fromDate(now);

    await _store.upsertRecord(
      collection: DevelopLocalCollection.backofficePendingPlans,
      id: id,
      payload: merged,
      createdAt: isNew ? now : null,
    );
    return id;
  }

  Future<void> delete(String id) async {
    await _store.deleteRecord(
      collection: DevelopLocalCollection.backofficePendingPlans,
      id: id,
    );
  }
}
