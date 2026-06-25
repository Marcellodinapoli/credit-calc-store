import 'package:flutter/foundation.dart';

import 'develop_public_usage_totals_sync.dart';
import 'develop_sync_config.dart';
import 'develop_sync_device.dart';
import 'develop_sync_firestore.dart';
import 'develop_sync_merge.dart';
import 'develop_sync_sqlite_store.dart';
import 'develop_sync_wire_record.dart';
import 'models/develop_local_collection.dart';

/// Motore push/pull tra SQLite locale e Firestore sync.
class DevelopSyncEngine {
  DevelopSyncEngine({
    required DevelopSyncSqliteStore store,
    required DevelopSyncFirestore remote,
  })  : _store = store,
        _remote = remote;

  final DevelopSyncSqliteStore _store;
  final DevelopSyncFirestore _remote;

  Future<int> pushAllLocal() async {
    final deviceId = await DevelopSyncDevice.id();
    final records = await _store.listAllRecordsForSync();
    var pushed = 0;

    for (final local in records) {
      final wire = DevelopSyncWireRecord(
        collection: local.collection,
        recordId: local.id,
        createdAtMs: local.createdAt.millisecondsSinceEpoch,
        updatedAtMs: local.updatedAt.millisecondsSinceEpoch,
        deviceId: deviceId,
        deleted: local.payload['_deleted'] == true,
        payload: local.payload['_deleted'] == true ? null : local.payload,
      );
      await _remote.upsertWireRecord(wire);
      pushed++;
    }

    await _store.setMeta(
      DevelopSyncConfig.metaLastPushedMs,
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
    return pushed;
  }

  Future<int> pullAndApply({int updatedAfterMs = 0}) async {
    final remoteRecords =
        await _remote.fetchRecordsUpdatedAfter(updatedAfterMs);
    var applied = 0;
    var maxRemoteMs = updatedAfterMs;

    for (final remote in remoteRecords) {
      final collection = remote.collection;
      if (collection == null) continue;
      if (!storeDevelopSyncedCollections.contains(collection)) continue;

      maxRemoteMs = remote.updatedAtMs > maxRemoteMs
          ? remote.updatedAtMs
          : maxRemoteMs;

      final local = await _store.recordById(
        collection: collection,
        id: remote.recordId,
      );

      if (!DevelopSyncMerge.remoteWins(local: local, remote: remote)) {
        continue;
      }

      if (remote.deleted) {
        await _store.applyRemoteDelete(collection: collection, id: remote.recordId);
        applied++;
        continue;
      }

      if (remote.payload == null) continue;

      await _store.applyRemoteRecord(
        collection: collection,
        id: remote.recordId,
        payload: remote.payload!,
        createdAt: DateTime.fromMillisecondsSinceEpoch(remote.createdAtMs),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(remote.updatedAtMs),
      );
      applied++;
    }

    if (maxRemoteMs > updatedAfterMs) {
      await _store.setMeta(
        DevelopSyncConfig.metaLastPulledMs,
        maxRemoteMs.toString(),
      );
    }

    if (applied > 0) {
      await DevelopPublicUsageTotalsSync.syncFromLocalStore(_store.userId);
    }

    return applied;
  }

  Future<DevelopSyncRunResult> fullSync() async {
    final lastPulled = int.tryParse(
          await _store.getMeta(DevelopSyncConfig.metaLastPulledMs) ?? '0',
        ) ??
        0;

    final pulled = await pullAndApply(
      updatedAfterMs: lastPulled > 0 ? lastPulled : 0,
    );
    final pushed = await pushAllLocal();
    await _remote.touchDevice();

    debugPrint(
      'DevelopSyncEngine: pull=$pulled push=$pushed (lastPulled=$lastPulled)',
    );

    return DevelopSyncRunResult(pulled: pulled, pushed: pushed);
  }

  Future<void> pushTombstone({
    required DevelopLocalCollection collection,
    required String recordId,
    required DateTime updatedAt,
  }) async {
    final deviceId = await DevelopSyncDevice.id();
    await _remote.upsertWireRecord(
      DevelopSyncWireRecord(
        collection: collection,
        recordId: recordId,
        createdAtMs: updatedAt.millisecondsSinceEpoch,
        updatedAtMs: updatedAt.millisecondsSinceEpoch,
        deviceId: deviceId,
        deleted: true,
      ),
    );
  }
}

class DevelopSyncRunResult {
  const DevelopSyncRunResult({required this.pulled, required this.pushed});

  final int pulled;
  final int pushed;
}
