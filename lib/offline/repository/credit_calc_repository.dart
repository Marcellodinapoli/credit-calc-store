import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart';

import '../models/sync_record_status.dart';
import '../services/local_database_service.dart';

class CreditCalcRecord {
  final String id;
  final Map<String, dynamic> data;

  const CreditCalcRecord({required this.id, required this.data});
}

/// Accesso dati operativi CreditCalc (creditori e pratiche) sul dispositivo.
class CreditCalcRepository {
  CreditCalcRepository._();
  static CreditCalcRepository? _instance;

  static CreditCalcRepository get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('CreditCalcRepository non inizializzato');
    }
    return i;
  }

  static void install({required String userId}) {
    _instance = CreditCalcRepository._().._userId = userId;
  }

  static void clear() => _instance = null;

  String get userId => _userId;

  String _userId = '';
  final _creditorsRevision = StreamController<int>.broadcast();
  final _calculationsRevision = StreamController<int>.broadcast();
  int _creditorsRev = 0;
  int _calculationsRev = 0;

  void notifyCreditorsChanged() {
    _creditorsRevision.add(++_creditorsRev);
  }

  void notifyCalculationsChanged() {
    _calculationsRevision.add(++_calculationsRev);
  }

  Stream<List<CreditCalcRecord>> watchCreditorRecords() {
    return _creditorsRevision.stream
        .asyncMap((_) => _loadLocalCreditors())
        .startWithFuture(_loadLocalCreditors());
  }

  Future<CreditCalcRecord?> getCreditor(String id) async {
    final row = await LocalDatabaseService.instance.recordById(
      collection: 'creditors',
      id: id,
    );
    if (row == null || row['payload']['_deleted'] == true) return null;
    return CreditCalcRecord(
      id: row['id'] as String,
      data: Map<String, dynamic>.from(row['payload'] as Map),
    );
  }

  Future<List<CreditCalcRecord>> _loadLocalCreditors() async {
    final rows = await LocalDatabaseService.instance.recordsForUser(
      userId: _userId,
      collection: 'creditors',
    );
    final records = rows
        .where((r) => r['payload']['_deleted'] != true)
        .map(
          (r) => CreditCalcRecord(
            id: r['id'] as String,
            data: Map<String, dynamic>.from(r['payload'] as Map),
          ),
        )
        .toList();
    return _sortCreditorRecords(records);
  }

  List<CreditCalcRecord> _sortCreditorRecords(List<CreditCalcRecord> records) {
    records.sort((a, b) {
      final aTs = a.data['createdAt'];
      final bTs = b.data['createdAt'];
      if (aTs is Timestamp && bTs is Timestamp) {
        return aTs.compareTo(bTs);
      }
      return 0;
    });
    return records;
  }

  Future<List<CreditCalcRecord>> listCreditorRecords() => _loadLocalCreditors();

  Future<void> saveCreditor({
    required String id,
    required Map<String, dynamic> data,
    bool isNew = false,
  }) async {
    data = Map<String, dynamic>.from(data);
    if (!isNew) {
      final existing = await getCreditor(id);
      if (existing != null) {
        data = {...existing.data, ...data};
      }
    }
    FirestoreUserScope.withOwner(data);
    final now = DateTime.now();

    await LocalDatabaseService.instance.upsertRecord(
      collection: 'creditors',
      id: id,
      userId: _userId,
      payload: {
        ...data,
        'createdAt': isNew ? Timestamp.fromDate(now) : data['createdAt'],
        'updatedAt': Timestamp.fromDate(now),
      },
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncRecordStatus.synced,
      origin: 'local',
    );
    notifyCreditorsChanged();
    PublicUsageLocalDataAccess.instance?.notifyChanged();
  }

  Future<void> deleteCreditor(String id) async {
    final existing = await LocalDatabaseService.instance.recordById(
      collection: 'creditors',
      id: id,
    );
    if (existing == null) return;

    final payload = Map<String, dynamic>.from(existing['payload'] as Map);
    payload['_deleted'] = true;

    await LocalDatabaseService.instance.upsertRecord(
      collection: 'creditors',
      id: id,
      userId: _userId,
      payload: payload,
      createdAt: existing['createdAt'] as DateTime,
      updatedAt: DateTime.now(),
      syncStatus: SyncRecordStatus.synced,
      origin: 'local',
    );
    notifyCreditorsChanged();
    PublicUsageLocalDataAccess.instance?.notifyChanged();
  }

  String newCreditorId() => DateTime.now().microsecondsSinceEpoch.toString();

  Stream<List<CreditCalcRecord>> watchCalculationRecords() {
    return _calculationsRevision.stream
        .asyncMap((_) => _loadLocalCalculations())
        .startWithFuture(_loadLocalCalculations());
  }

  Future<CreditCalcRecord?> getCalculation(String id) async {
    final row = await LocalDatabaseService.instance.recordById(
      collection: 'calculations',
      id: id,
    );
    if (row == null || row['payload']['_deleted'] == true) return null;
    return CreditCalcRecord(
      id: row['id'] as String,
      data: Map<String, dynamic>.from(row['payload'] as Map),
    );
  }

  Future<List<CreditCalcRecord>> getCalculationRecords() =>
      _loadLocalCalculations();

  Future<List<CreditCalcRecord>> _loadLocalCalculations() async {
    final rows = await LocalDatabaseService.instance.recordsForUser(
      userId: _userId,
      collection: 'calculations',
    );
    return rows
        .where((r) => r['payload']['_deleted'] != true)
        .map(
          (r) => CreditCalcRecord(
            id: r['id'] as String,
            data: Map<String, dynamic>.from(r['payload'] as Map),
          ),
        )
        .toList();
  }

  Future<void> saveCalculation({
    required String id,
    required Map<String, dynamic> data,
    bool isNew = false,
  }) async {
    data = Map<String, dynamic>.from(data);
    if (!isNew) {
      final existing = await getCalculation(id);
      if (existing != null) {
        data = {...existing.data, ...data};
      }
    }
    FirestoreUserScope.withOwner(data);
    final now = DateTime.now();

    await LocalDatabaseService.instance.upsertRecord(
      collection: 'calculations',
      id: id,
      userId: _userId,
      payload: {
        ...data,
        'createdAt': isNew ? Timestamp.fromDate(now) : data['createdAt'],
        'updatedAt': Timestamp.fromDate(now),
      },
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncRecordStatus.synced,
      origin: 'local',
    );
    notifyCalculationsChanged();
  }

  Future<void> deleteCalculation(String id) async {
    final existing = await LocalDatabaseService.instance.recordById(
      collection: 'calculations',
      id: id,
    );
    if (existing == null) return;

    final payload = Map<String, dynamic>.from(existing['payload'] as Map);
    payload['_deleted'] = true;

    await LocalDatabaseService.instance.upsertRecord(
      collection: 'calculations',
      id: id,
      userId: _userId,
      payload: payload,
      createdAt: existing['createdAt'] as DateTime,
      updatedAt: DateTime.now(),
      syncStatus: SyncRecordStatus.synced,
      origin: 'local',
    );
    notifyCalculationsChanged();
  }

  Future<List<String>> createCalculationsBatch(
    List<Map<String, dynamic>> payloads,
  ) async {
    final now = DateTime.now();
    final ids = <String>[];
    for (final payload in payloads) {
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      ids.add(id);
      await LocalDatabaseService.instance.upsertRecord(
        collection: 'calculations',
        id: id,
        userId: _userId,
        payload: {
          ...payload,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        },
        createdAt: now,
        updatedAt: now,
        syncStatus: SyncRecordStatus.synced,
        origin: 'local',
      );
      await Future<void>.delayed(const Duration(microseconds: 2));
    }
    notifyCalculationsChanged();
    return ids;
  }

  Future<void> deleteCalculationsBatch(List<String> ids) async {
    for (final id in ids) {
      await deleteCalculation(id);
    }
  }

  Future<int> localRecordCount() async {
    final creditors = await LocalDatabaseService.instance.recordsForUser(
      userId: _userId,
      collection: 'creditors',
    );
    final calculations = await LocalDatabaseService.instance.recordsForUser(
      userId: _userId,
      collection: 'calculations',
    );
    var count = 0;
    for (final row in creditors) {
      if (row['payload']['_deleted'] != true) count++;
    }
    for (final row in calculations) {
      if (row['payload']['_deleted'] != true) count++;
    }
    return count;
  }
}

extension<T> on Stream<T> {
  Stream<T> startWithFuture(Future<T> future) async* {
    yield await future;
    yield* this;
  }
}
