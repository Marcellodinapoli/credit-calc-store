import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/sync_record_status.dart';
import '../services/local_database_service.dart';
import 'models/develop_local_collection.dart';
import 'models/develop_local_record.dart';

typedef DevelopLocalMutationListener = void Function(
  DevelopLocalCollection collection,
  String id, {
  required bool deleted,
  DateTime? updatedAt,
});

/// Adapter SQLite per sync multi-dispositivo e storage locale itinerario.
class DevelopSyncSqliteStore {
  DevelopSyncSqliteStore(this.userId);

  final String userId;
  final _db = LocalDatabaseService.instance;
  final _revisionControllers =
      <DevelopLocalCollection, StreamController<int>>{};
  var _applyingRemoteSync = false;

  DevelopLocalMutationListener? onMutation;

  Stream<int> watchRevision(DevelopLocalCollection collection) async* {
    yield 0;
    yield* _revisionControllers
        .putIfAbsent(
          collection,
          () => StreamController<int>.broadcast(),
        )
        .stream;
  }

  void _notifyRevision(DevelopLocalCollection collection) {
    final controller = _revisionControllers[collection];
    if (controller == null || controller.isClosed) return;
    controller.add(DateTime.now().millisecondsSinceEpoch);
  }

  /// Aggiorna gli stream UI dopo import esterni (es. trasferimento manuale).
  void notifyRevisionsForStorageKeys(Iterable<String> storageKeys) {
    for (final key in storageKeys) {
      final collection = DevelopLocalCollectionCodec.fromStorageKey(key);
      if (collection != null) _notifyRevision(collection);
    }
  }

  void notifyAllDevelopRevisions() {
    for (final collection in storeDevelopSyncedCollections) {
      _notifyRevision(collection);
    }
  }

  Future<List<DevelopLocalRecord>> recordsForCollection(
    DevelopLocalCollection collection,
  ) async {
    final rows = await _db.recordsForUser(
      userId: userId,
      collection: collection.storageKey,
    );
    final out = <DevelopLocalRecord>[];
    for (final row in rows) {
      final record = _rowToRecord(row);
      if (record == null) continue;
      if (record.payload['_deleted'] == true) continue;
      out.add(record);
    }
    return out;
  }

  Future<List<DevelopLocalRecord>> listAllRecordsForSync() async {
    final rows = await _db.listAllRecordsForUser(userId);
    final out = <DevelopLocalRecord>[];
    for (final row in rows) {
      final record = _rowToRecord(row);
      if (record == null) continue;
      if (!storeDevelopSyncedCollections.contains(record.collection)) continue;
      out.add(record);
    }
    return out;
  }

  Future<DevelopLocalRecord?> recordById({
    required DevelopLocalCollection collection,
    required String id,
  }) async {
    final row = await _db.recordById(collection: collection.storageKey, id: id);
    if (row == null) return null;
    return _rowToRecord(row);
  }

  Future<void> upsertRecord({
    required DevelopLocalCollection collection,
    required String id,
    required Map<String, dynamic> payload,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) async {
    final now = DateTime.now();
    final existing = await recordById(collection: collection, id: id);
    final created = createdAt ?? existing?.createdAt ?? now;
    var updated = updatedAt ?? now;
    if (!_applyingRemoteSync && existing != null) {
      final existingMs = existing.updatedAt.millisecondsSinceEpoch;
      if (updated.millisecondsSinceEpoch <= existingMs) {
        updated = DateTime.fromMillisecondsSinceEpoch(existingMs + 1);
      }
    }
    if (!_applyingRemoteSync) {
      payload = Map<String, dynamic>.from(payload)
        ..['updatedAt'] = Timestamp.fromDate(updated);
    }

    await _db.upsertRecord(
      collection: collection.storageKey,
      id: id,
      userId: userId,
      payload: payload,
      createdAt: created,
      updatedAt: updated,
      syncStatus: SyncRecordStatus.synced,
      origin: 'local',
    );
    _notifyRevision(collection);
    if (!_applyingRemoteSync) {
      onMutation?.call(collection, id, deleted: false, updatedAt: updated);
    }
  }

  Future<void> deleteRecord({
    required DevelopLocalCollection collection,
    required String id,
  }) async {
    final now = DateTime.now();
    final existing = await recordById(collection: collection, id: id);
    if (existing == null) return;

    var updated = now;
    final existingMs = existing.updatedAt.millisecondsSinceEpoch;
    if (updated.millisecondsSinceEpoch <= existingMs) {
      updated = DateTime.fromMillisecondsSinceEpoch(existingMs + 1);
    }

    final payload = Map<String, dynamic>.from(existing.payload)
      ..['_deleted'] = true
      ..['updatedAt'] = Timestamp.fromDate(updated);

    await _db.upsertRecord(
      collection: collection.storageKey,
      id: id,
      userId: userId,
      payload: payload,
      createdAt: existing.createdAt,
      updatedAt: updated,
      syncStatus: SyncRecordStatus.synced,
      origin: 'local',
    );
    _notifyRevision(collection);
    if (!_applyingRemoteSync) {
      onMutation?.call(collection, id, deleted: true, updatedAt: updated);
    }
  }

  Future<void> applyRemoteRecord({
    required DevelopLocalCollection collection,
    required String id,
    required Map<String, dynamic> payload,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) async {
    _applyingRemoteSync = true;
    try {
      await _db.upsertRecord(
        collection: collection.storageKey,
        id: id,
        userId: userId,
        payload: payload,
        createdAt: createdAt,
        updatedAt: updatedAt,
        syncStatus: SyncRecordStatus.synced,
        origin: 'develop_sync',
      );
      _notifyRevision(collection);
    } finally {
      _applyingRemoteSync = false;
    }
  }

  Future<void> applyRemoteDelete({
    required DevelopLocalCollection collection,
    required String id,
  }) async {
    _applyingRemoteSync = true;
    try {
      await _db.deleteRecord(collection: collection.storageKey, id: id);
      _notifyRevision(collection);
    } finally {
      _applyingRemoteSync = false;
    }
  }

  Future<String?> getMeta(String key) => _db.getMeta(key);

  Future<void> setMeta(String key, String value) => _db.setMeta(key, value);

  void notifyLocalMutation(
    DevelopLocalCollection collection,
    String id, {
    required bool deleted,
    DateTime? updatedAt,
  }) {
    if (_applyingRemoteSync) return;
    onMutation?.call(
      collection,
      id,
      deleted: deleted,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  DevelopLocalRecord? _rowToRecord(Map<String, dynamic> row) {
    final collection = DevelopLocalCollectionCodec.fromStorageKey(
      row['collection'] as String?,
    );
    if (collection == null) return null;
    return DevelopLocalRecord(
      id: row['id'] as String,
      collection: collection,
      userId: row['userId'] as String,
      payload: Map<String, dynamic>.from(row['payload'] as Map),
      createdAt: row['createdAt'] as DateTime,
      updatedAt: row['updatedAt'] as DateTime,
    );
  }
}
