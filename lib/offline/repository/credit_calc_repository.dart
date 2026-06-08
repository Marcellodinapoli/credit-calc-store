import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart';

import '../credit_calc_runtime.dart';
import '../exceptions/session_write_blocked_exception.dart';
import '../models/credit_calc_mode.dart';
import '../models/sync_record_status.dart';
import '../services/connectivity_service.dart';
import '../services/local_database_service.dart';
import '../services/mode_preferences_service.dart';
import '../services/session_service.dart';
import '../services/sync_engine.dart';

class CreditCalcRecord {
  final String id;
  final Map<String, dynamic> data;

  const CreditCalcRecord({required this.id, required this.data});
}

/// Accesso dati CreditCalc con routing Web / Offline.
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

  static void install({
    required CreditCalcMode mode,
    required String userId,
    required ModePreferencesService modePrefs,
    required SessionService sessionService,
    required SyncEngine syncEngine,
  }) {
    _instance = CreditCalcRepository._()
      .._mode = mode
      .._userId = userId
      .._sessionService = sessionService
      .._syncEngine = syncEngine;
  }

  static void clear() => _instance = null;

  CreditCalcMode _mode = CreditCalcMode.web;
  String _userId = '';
  SessionService? _sessionService;
  SyncEngine? _syncEngine;
  final _creditorsRevision = StreamController<int>.broadcast();
  final _calculationsRevision = StreamController<int>.broadcast();
  int _creditorsRev = 0;
  int _calculationsRev = 0;

  CreditCalcMode get mode => _mode;
  bool get isOfflineMode => _mode == CreditCalcMode.offlineSync;

  void notifyCreditorsChanged() {
    _creditorsRevision.add(++_creditorsRev);
    unawaited(CreditCalcRuntime.refreshPendingSyncCount());
  }

  void notifyCalculationsChanged() {
    _calculationsRevision.add(++_calculationsRev);
    unawaited(CreditCalcRuntime.refreshPendingSyncCount());
  }

  Future<void> _assertCanWrite() async {
    final session = _sessionService;
    if (session == null) return;
    if (!await session.holdsActiveSession()) {
      const message =
          'La sessione CreditCalc è attiva su un altro dispositivo. '
          'Chiudi e riapri CreditCalc qui, poi scegli «Continua qui».';
      CreditCalcRuntime.notifyWriteBlocked(message);
      throw SessionWriteBlockedException(message);
    }
  }

  Future<void> _maybeSync() async {
    if (!await ConnectivityService.isOnline()) return;
    final session = _sessionService;
    if (session != null && !await session.holdsActiveSession()) return;
    unawaited(_syncEngine?.syncPendingChanges());
  }

  // --- Creditori ---

  Stream<List<CreditCalcRecord>> watchCreditorRecords() {
    if (!isOfflineMode) {
      return FirestoreUserScope.creditorsOrdered().snapshots().map((snap) {
        return _sortCreditorRecords(
          snap.docs
              .map((d) => CreditCalcRecord(id: d.id, data: d.data()))
              .toList(),
        );
      });
    }
    return _creditorsRevision.stream
        .asyncMap((_) => _loadLocalCreditors())
        .startWithFuture(_loadLocalCreditors());
  }

  Future<CreditCalcRecord?> getCreditor(String id) async {
    if (!isOfflineMode) {
      final doc =
          await FirebaseFirestore.instance.collection('creditors').doc(id).get();
      if (!doc.exists) return null;
      return CreditCalcRecord(id: doc.id, data: doc.data() ?? {});
    }
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

  Future<List<CreditCalcRecord>> listCreditorRecords() async {
    if (!isOfflineMode) {
      final snap = await FirestoreUserScope.creditorsOrdered().get();
      return _sortCreditorRecords(
        snap.docs
            .map((d) => CreditCalcRecord(id: d.id, data: d.data()))
            .toList(),
      );
    }
    return _loadLocalCreditors();
  }

  Future<void> saveCreditor({
    required String id,
    required Map<String, dynamic> data,
    bool isNew = false,
  }) async {
    await _assertCanWrite();
    data = Map<String, dynamic>.from(data);
    if (!isNew) {
      final existing = await getCreditor(id);
      if (existing != null) {
        data = {...existing.data, ...data};
      }
    }
    FirestoreUserScope.withOwner(data);
    final now = DateTime.now();

    if (!isOfflineMode) {
      final ref = FirebaseFirestore.instance.collection('creditors').doc(id);
      if (isNew) data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      await ref.set(data, SetOptions(merge: true));
      return;
    }

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
      syncStatus: SyncRecordStatus.pending,
      origin: 'local',
    );
    notifyCreditorsChanged();
    await _maybeSync();
  }

  Future<void> deleteCreditor(String id) async {
    await _assertCanWrite();
    if (!isOfflineMode) {
      await FirebaseFirestore.instance.collection('creditors').doc(id).delete();
      return;
    }

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
      syncStatus: SyncRecordStatus.pending,
      origin: 'local',
    );
    notifyCreditorsChanged();
    await _maybeSync();
  }

  String newCreditorId() {
    if (!isOfflineMode) {
      return FirebaseFirestore.instance.collection('creditors').doc().id;
    }
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  // --- Calculations / pratiche ---

  Stream<List<CreditCalcRecord>> watchCalculationRecords() {
    if (!isOfflineMode) {
      return FirestoreUserScope.userCalculations().snapshots().map(
            (snap) => snap.docs
                .map((d) => CreditCalcRecord(id: d.id, data: d.data()))
                .toList(),
          );
    }
    return _calculationsRevision.stream
        .asyncMap((_) => _loadLocalCalculations())
        .startWithFuture(_loadLocalCalculations());
  }

  Future<CreditCalcRecord?> getCalculation(String id) async {
    if (!isOfflineMode) {
      final doc = await FirebaseFirestore.instance
          .collection('calculations')
          .doc(id)
          .get();
      if (!doc.exists) return null;
      return CreditCalcRecord(id: doc.id, data: doc.data() ?? {});
    }
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

  Future<List<CreditCalcRecord>> getCalculationRecords() async {
    if (!isOfflineMode) {
      final snap = await FirestoreUserScope.userCalculations().get();
      return snap.docs
          .map((d) => CreditCalcRecord(id: d.id, data: d.data()))
          .toList();
    }
    return _loadLocalCalculations();
  }

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
    await _assertCanWrite();
    data = Map<String, dynamic>.from(data);
    if (!isNew) {
      final existing = await getCalculation(id);
      if (existing != null) {
        data = {...existing.data, ...data};
      }
    }
    FirestoreUserScope.withOwner(data);
    final now = DateTime.now();

    if (!isOfflineMode) {
      final ref = FirebaseFirestore.instance.collection('calculations').doc(id);
      if (isNew) data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      await ref.set(data, SetOptions(merge: true));
      return;
    }

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
      syncStatus: SyncRecordStatus.pending,
      origin: 'local',
    );
    notifyCalculationsChanged();
    await _maybeSync();
  }

  Future<void> deleteCalculation(String id) async {
    await _assertCanWrite();
    if (!isOfflineMode) {
      await FirebaseFirestore.instance.collection('calculations').doc(id).delete();
      return;
    }

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
      syncStatus: SyncRecordStatus.pending,
      origin: 'local',
    );
    notifyCalculationsChanged();
    await _maybeSync();
  }

  Future<List<String>> createCalculationsBatch(
    List<Map<String, dynamic>> payloads,
  ) async {
    await _assertCanWrite();
    if (!isOfflineMode) {
      final batch = FirebaseFirestore.instance.batch();
      final collection = FirebaseFirestore.instance.collection('calculations');
      final now = FieldValue.serverTimestamp();
      final ids = <String>[];
      for (final payload in payloads) {
        final ref = collection.doc();
        final data = Map<String, dynamic>.from(payload);
        data['createdAt'] = now;
        data['updatedAt'] = now;
        batch.set(ref, data);
        ids.add(ref.id);
      }
      await batch.commit();
      return ids;
    }

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
        syncStatus: SyncRecordStatus.pending,
        origin: 'local',
      );
      await Future<void>.delayed(const Duration(microseconds: 2));
    }
    notifyCalculationsChanged();
    await _maybeSync();
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

  Future<int> pendingCount() async {
    final pending =
        await LocalDatabaseService.instance.pendingRecords(_userId);
    return pending
        .where((row) => row['collection'] != 'plan_drafts')
        .length;
  }
}

extension<T> on Stream<T> {
  Stream<T> startWithFuture(Future<T> future) async* {
    yield await future;
    yield* this;
  }
}
