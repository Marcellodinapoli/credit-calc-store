import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../develop_sync/develop_sync_crypto.dart';
import '../develop_sync/develop_sync_device.dart';
import '../utils/firestore_json_codec.dart';
import '../develop_sync/develop_sync_coordinator.dart';
import '../credit_calc_repository_setup.dart';
import '../device_public_usage_local_data_access.dart';
import '../models/sync_record_status.dart';
import '../services/local_database_service.dart';
import 'device_transfer_config.dart';
import 'device_transfer_models.dart';

/// Trasferimento una tantum: ponte effimero su Firebase, merge incrementale in locale.
abstract final class DeviceTransferService {
  static final _firestore = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _transferRef(String userId) =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('device_transfer')
          .doc(DeviceTransferConfig.transferDocId);

  static CollectionReference<Map<String, dynamic>> _chunksRef(String userId) =>
      _transferRef(userId).collection('chunks');

  static CollectionReference<Map<String, dynamic>> _presenceRef(String userId) =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('device_transfer_presence');

  static String _companyNameKey(String collection, String id) =>
      '$collection::$id';

  static String? _readCompanyName(Map<String, dynamic> payload) {
    for (final key in const ['companyName', 'ragioneSociale', 'name']) {
      final raw = payload[key];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    }
    return null;
  }

  static Map<String, dynamic> _payloadWithoutCompanyName(
    Map<String, dynamic> payload,
  ) {
    final copy = Map<String, dynamic>.from(payload);
    copy.remove('companyName');
    copy.remove('ragioneSociale');
    return copy;
  }

  static Map<String, String> _filterAppMeta(Map<String, String> meta) {
    return Map.fromEntries(
      meta.entries.where(
        (e) => !e.key.startsWith(DeviceTransferConfig.cipherMetaPrefix),
      ),
    );
  }

  static Future<int> readLastSyncAtMs(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('${userId}_${DeviceTransferConfig.prefsLastSyncAt}') ?? 0;
  }

  static Future<void> _saveLastSyncAt(String userId, int syncAtMs) async {
    if (syncAtMs <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '${userId}_${DeviceTransferConfig.prefsLastSyncAt}',
      syncAtMs,
    );
  }

  static Future<DeviceTransferLocalState> readLocalState(String userId) async {
    final lastSyncAtMs = await readLastSyncAtMs(userId);
    final db = LocalDatabaseService.instance;
    final maxUpdatedAtMs = await db.maxUpdatedAtMsForUser(userId);
    final pendingChangeCount = await db.countChangesSince(userId, lastSyncAtMs);
    final localRecordCount = await db.countRecordsForUser(userId);
    return DeviceTransferLocalState(
      lastSyncAtMs: lastSyncAtMs,
      maxUpdatedAtMs: maxUpdatedAtMs,
      pendingChangeCount: pendingChangeCount,
      localRecordCount: localRecordCount,
    );
  }

  static DeviceTransferPeerState? _readPeerFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
    String localDeviceId,
  ) {
    final maxAgeMs = DeviceTransferConfig.presenceMaxAgeSeconds * 1000;
    final now = DateTime.now().millisecondsSinceEpoch;
    DeviceTransferPeerState? best;
    for (final doc in snap.docs) {
      if (doc.id == localDeviceId) continue;
      final at = (doc.data()['lastSeenAtMs'] as num?)?.toInt() ?? 0;
      if (at <= 0 || now - at > maxAgeMs) continue;
      final peer = DeviceTransferPeerState.fromFirestore(doc.id, doc.data());
      if (best == null || peer.lastSeenAtMs > best.lastSeenAtMs) {
        best = peer;
      }
    }
    return best;
  }

  static Future<DeviceTransferPeerState?> readPeerState(
    String userId, {
    bool preferServer = false,
  }) async {
    final localId = await DevelopSyncDevice.id();
    final snap = preferServer
        ? await _presenceRef(userId).get(
            const GetOptions(source: Source.server),
          )
        : await _presenceRef(userId).get();
    return _readPeerFromSnapshot(snap, localId);
  }

  static Stream<DeviceTransferPeerState?> watchPeerState(String userId) async* {
    final localId = await DevelopSyncDevice.id();
    await for (final snap in _presenceRef(userId).snapshots()) {
      yield _readPeerFromSnapshot(snap, localId);
    }
  }

  static String resolveTransferMode({
    required DeviceTransferLocalState local,
    DeviceTransferPeerState? peer,
  }) {
    return 'delta';
  }

  /// Record locali modificati dopo l'ultimo allineamento di questo dispositivo.
  static int resolveSinceMs({
    required DeviceTransferLocalState local,
    DeviceTransferPeerState? peer,
  }) {
    if (local.neverSynced) return 0;
    if (peer == null) return local.lastSyncAtMs;
    return local.lastSyncAtMs;
  }

  static Future<DeviceTransferSyncHint> adviseSync(String userId) async {
    final local = await readLocalState(userId);
    final peer = await readPeerState(userId);
    final exchange =
        peer == null ? null : await exchangeCounts(userId, peer);
    return DeviceTransferSyncAdvisor.advise(
      local: local,
      peer: peer,
      exchange: exchange,
    );
  }

  static Future<DeviceTransferExchangeCounts> exchangeCounts(
    String userId,
    DeviceTransferPeerState peer,
  ) async {
    final local = await readLocalState(userId);
    final db = LocalDatabaseService.instance;
    final localIndex = await db.recordVersionIndexForUser(
      userId,
      maxEntries: DeviceTransferConfig.maxPresenceRecordVersions,
    );

    final localToSend = (await resolveRecordsToSend(
      userId,
      peer: peer,
      local: local,
    )).length;

    var peerToSend = !localIndex.truncated && localIndex.versions.isNotEmpty
        ? LocalDatabaseService.countRecordsNewerThanPeer(
            peer.recordVersions,
            localIndex.versions,
          )
        : peer.pendingChangeCount;

    if (peer.pendingChangeCount > peerToSend) {
      peerToSend = peer.pendingChangeCount;
    }

    return DeviceTransferExchangeCounts(
      localToSend: localToSend,
      peerToSend: peerToSend,
    );
  }

  static Future<List<Map<String, dynamic>>> resolveRecordsToSend(
    String userId, {
    DeviceTransferPeerState? peer,
    required DeviceTransferLocalState local,
  }) async {
    final db = LocalDatabaseService.instance;
    final sinceMs = peer != null
        ? resolveSinceMs(local: local, peer: peer)
        : (local.neverSynced ? 0 : local.lastSyncAtMs);
    final peerVersions =
        peer != null && peer.hasReliableVersionIndex ? peer.recordVersions : null;
    return db.recordsPendingSync(
      userId,
      sinceMs: sinceMs,
      peerVersions: peerVersions,
    );
  }

  static Future<DeviceTransferLocalHistory> readLocalHistory(
    String userId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = '${userId}_';
    DateTime? readMs(String key) {
      final raw = prefs.getInt('$prefix$key');
      if (raw == null || raw <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }

    return DeviceTransferLocalHistory(
      lastSendAt: readMs(DeviceTransferConfig.prefsLastSendAt),
      lastSendBytes: prefs.getInt('$prefix${DeviceTransferConfig.prefsLastSendBytes}'),
      lastReceiveAt: readMs(DeviceTransferConfig.prefsLastReceiveAt),
      lastReceiveSentAt: readMs(DeviceTransferConfig.prefsLastReceiveSentAt),
      lastReceiveBytes:
          prefs.getInt('$prefix${DeviceTransferConfig.prefsLastReceiveBytes}'),
    );
  }

  static Future<void> _saveLastSend({
    required String userId,
    required DateTime sentAt,
    required int totalBytes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = '${userId}_';
    await prefs.setInt(
      '$prefix${DeviceTransferConfig.prefsLastSendAt}',
      sentAt.millisecondsSinceEpoch,
    );
    await prefs.setInt(
      '$prefix${DeviceTransferConfig.prefsLastSendBytes}',
      totalBytes,
    );
  }

  static Future<void> _saveLastReceive({
    required String userId,
    required DateTime sentAt,
    required DateTime receivedAt,
    required int totalBytes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = '${userId}_';
    await prefs.setInt(
      '$prefix${DeviceTransferConfig.prefsLastReceiveAt}',
      receivedAt.millisecondsSinceEpoch,
    );
    await prefs.setInt(
      '$prefix${DeviceTransferConfig.prefsLastReceiveSentAt}',
      sentAt.millisecondsSinceEpoch,
    );
    await prefs.setInt(
      '$prefix${DeviceTransferConfig.prefsLastReceiveBytes}',
      totalBytes,
    );
  }

  static Future<DeviceTransferMeta?> readPendingMeta(String userId) async {
    final meta = await readTransferMeta(userId);
    if (meta == null || !meta.isReceivable) return null;
    return meta;
  }

  static Future<DeviceTransferMeta?> readTransferMeta(String userId) async {
    final snap = await _transferRef(userId).get();
    if (!snap.exists) return null;
    return _metaFromSnapshot(snap.data() ?? {});
  }

  static DeviceTransferMeta? _metaFromSnapshot(Map<String, dynamic> data) {
    final meta = DeviceTransferMeta.fromFirestore(data);
    if (meta.isExpired) return null;
    if (meta.isPrepared || meta.isPending) return meta;
    return null;
  }

  static Stream<DeviceTransferMeta?> watchTransferMeta(String userId) {
    return _transferRef(userId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return _metaFromSnapshot(snap.data() ?? {});
    });
  }

  static Future<bool> isActiveSender(String userId) async {
    final meta = await readTransferMeta(userId);
    if (meta == null || (!meta.isPrepared && !meta.isPending)) return false;
    final deviceId = await DevelopSyncDevice.id();
    return meta.senderDeviceId == deviceId;
  }

  static Stream<bool> watchReceiverReady(String userId) async* {
    final senderId = await DevelopSyncDevice.id();
    final maxAgeMs = DeviceTransferConfig.presenceMaxAgeSeconds * 1000;
    await for (final snap in _presenceRef(userId).snapshots()) {
      final now = DateTime.now().millisecondsSinceEpoch;
      var ready = false;
      for (final doc in snap.docs) {
        if (doc.id == senderId) continue;
        final at = (doc.data()['lastSeenAtMs'] as num?)?.toInt() ?? 0;
        if (at > 0 && now - at <= maxAgeMs) {
          ready = true;
          break;
        }
      }
      yield ready;
    }
  }

  static Future<void> pingReceiverPresence(String userId) async {
    final deviceId = await DevelopSyncDevice.id();
    final state = await readLocalState(userId);
    final versionIndex = await LocalDatabaseService.instance
        .recordVersionIndexForUser(
      userId,
      maxEntries: DeviceTransferConfig.maxPresenceRecordVersions,
    );
    try {
      await _presenceRef(userId).doc(deviceId).set({
        'lastSeenAtMs': DateTime.now().millisecondsSinceEpoch,
        'onSyncPage': true,
        'lastSyncAtMs': state.lastSyncAtMs,
        'maxUpdatedAtMs': state.maxUpdatedAtMs,
        'pendingChangeCount': state.pendingChangeCount,
        'localRecordCount': state.localRecordCount,
        'recordVersions': versionIndex.versions,
        'recordVersionsTruncated': versionIndex.truncated,
      }, SetOptions(merge: true));
    } catch (e, st) {
      debugPrint('DeviceTransferService: pingReceiverPresence failed: $e\n$st');
    }
  }

  static Future<void> clearReceiverPresence(String userId) async {
    final deviceId = await DevelopSyncDevice.id();
    await _presenceRef(userId).doc(deviceId).delete();
  }

  static Future<void> _deleteRemotePackage(String userId) async {
    final chunks = await _chunksRef(userId).get();
    for (var i = 0; i < chunks.docs.length; i += 450) {
      final batch = _firestore.batch();
      for (final doc in chunks.docs.skip(i).take(450)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    await _transferRef(userId).delete();
  }

  static Future<DeviceTransferPrepareResult> preparePackage(
    String userId,
  ) async {
    final local = await readLocalState(userId);
    final peer = await readPeerState(userId);

    final toSend = await resolveRecordsToSend(
      userId,
      peer: peer,
      local: local,
    );
    if (toSend.isEmpty) {
      throw StateError(
        'Nessun record da inviare: l\'altro dispositivo ha già tutti i tuoi dati.',
      );
    }

    final transferMode = resolveTransferMode(local: local, peer: peer);
    final isDelta = toSend.length < local.localRecordCount;

    final built = await _buildAndUploadPackage(
      userId: userId,
      status: 'prepared',
      transferMode: transferMode,
      rows: toSend,
      isDelta: isDelta,
    );
    return DeviceTransferPrepareResult(
      recordCount: built.recordCount,
      totalBytes: built.totalBytes,
      companyNames: built.companyNames,
      preparedAt: built.timestamp,
      isDelta: isDelta,
      pendingChanges: toSend.length,
    );
  }

  static Future<DeviceTransferSendResult> releasePackage(String userId) async {
    final snap = await _transferRef(userId).get();
    if (!snap.exists) {
      throw StateError('Nessun pacchetto preparato da inviare.');
    }
    final meta = DeviceTransferMeta.fromFirestore(snap.data() ?? {});
    if (!meta.isPrepared) {
      throw StateError('Il pacchetto non è in stato di invio.');
    }
    final deviceId = await DevelopSyncDevice.id();
    if (meta.senderDeviceId != deviceId) {
      throw StateError('Questo pacchetto è stato preparato su un altro dispositivo.');
    }
    if (meta.isExpired) {
      await _deleteRemotePackage(userId);
      throw StateError('Il pacchetto è scaduto. Prepara un nuovo trasferimento.');
    }

    final now = DateTime.now();
    final expiresAt = now.add(
      const Duration(minutes: DeviceTransferConfig.ttlMinutes),
    );
    final syncBaselineMs = now.millisecondsSinceEpoch;
    await _transferRef(userId).set({
      'status': 'pending',
      'releasedAtMs': syncBaselineMs,
      'expiresAtMs': expiresAt.millisecondsSinceEpoch,
      'syncBaselineMs': syncBaselineMs,
    }, SetOptions(merge: true));

    await _saveLastSend(
      userId: userId,
      sentAt: now,
      totalBytes: meta.totalBytes,
    );
    final alignedAtMs = meta.maxPreparedUpdatedAtMs ?? syncBaselineMs;
    await _saveLastSyncAt(userId, alignedAtMs);

    return DeviceTransferSendResult(
      recordCount: meta.recordCount,
      chunkCount: meta.chunkCount,
      sentAt: now,
      expiresAt: expiresAt,
      totalBytes: meta.totalBytes,
      companyNames: meta.companyNames.values.take(12).toList(),
    );
  }

  static Future<_BuiltPackage> _buildAndUploadPackage({
    required String userId,
    required String status,
    required String transferMode,
    required List<Map<String, dynamic>> rows,
    required bool isDelta,
  }) async {
    await _deleteRemotePackage(userId);

    final appMeta = _filterAppMeta(
      await LocalDatabaseService.instance.listAllMeta(),
    );
    final usageAccess = DevicePublicUsageLocalDataAccess(userId);
    final publicUsage = await _readPublicUsage(usageAccess);

    final wireRecords = <Map<String, dynamic>>[];
    final companyNames = <String, String>{};
    final companyPreview = <String>{};

    for (final row in rows) {
      final collection = row['collection'] as String;
      final id = row['id'] as String;
      final payload = Map<String, dynamic>.from(row['payload'] as Map);
      final isDeleted = payload['_deleted'] == true;

      if (!isDeleted) {
        final company = _readCompanyName(payload);
        if (company != null) {
          companyNames[_companyNameKey(collection, id)] = company;
          companyPreview.add(company);
        }
      }

      wireRecords.add({
        'collection': collection,
        'id': id,
        'payload': isDeleted
            ? const {'_deleted': true}
            : _payloadWithoutCompanyName(payload),
        'createdAtMs': (row['createdAt'] as DateTime).millisecondsSinceEpoch,
        'updatedAtMs': (row['updatedAt'] as DateTime).millisecondsSinceEpoch,
        'serverUpdatedAtMs':
            (row['serverUpdatedAt'] as DateTime?)?.millisecondsSinceEpoch,
        'syncStatus': row['syncStatus'] is SyncRecordStatus
            ? (row['syncStatus'] as SyncRecordStatus).storageValue
            : row['syncStatus']?.toString() ?? 'synced',
        'origin': row['origin'] ?? 'local',
      });
    }

    final chunks = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < wireRecords.length; i += DeviceTransferConfig.recordsPerChunk) {
      final end = (i + DeviceTransferConfig.recordsPerChunk < wireRecords.length)
          ? i + DeviceTransferConfig.recordsPerChunk
          : wireRecords.length;
      chunks.add(wireRecords.sublist(i, end));
    }
    if (chunks.isEmpty) {
      throw StateError('Nessun record da trasferire.');
    }

    final senderDeviceId = await DevelopSyncDevice.id();
    final now = DateTime.now();
    var maxPreparedUpdatedAtMs = 0;
    for (final row in rows) {
      final updatedAt = row['updatedAt'];
      if (updatedAt is! DateTime) continue;
      final ms = updatedAt.millisecondsSinceEpoch;
      if (ms > maxPreparedUpdatedAtMs) maxPreparedUpdatedAtMs = ms;
    }
    final expiresAt = now.add(
      const Duration(minutes: DeviceTransferConfig.ttlMinutes),
    );
    var totalBytes = 0;

    for (var i = 0; i < chunks.length; i++) {
      final chunkPayload = <String, dynamic>{
        'schemaVersion': DeviceTransferConfig.schemaVersion,
        'chunkIndex': i,
        'records': chunks[i],
      };
      if (i == 0) {
        chunkPayload['appMeta'] = appMeta;
        if (publicUsage.isNotEmpty) chunkPayload['publicUsage'] = publicUsage;
      }

      final encoded = FirestoreJsonCodec.encodeMap(chunkPayload);
      final encrypted = await DevelopSyncCrypto.encryptPayload(userId, encoded);
      final payloadBytes = utf8.encode(encrypted).length;
      totalBytes += payloadBytes;
      await _chunksRef(userId).doc('$i').set({
        'chunkIndex': i,
        'payload': encrypted,
        'payloadBytes': payloadBytes,
      });
    }

    await _transferRef(userId).set({
      'status': status,
      'schemaVersion': DeviceTransferConfig.schemaVersion,
      'transferMode': transferMode,
      'isDelta': isDelta,
      'createdAtMs': now.millisecondsSinceEpoch,
      'expiresAtMs': expiresAt.millisecondsSinceEpoch,
      'senderDeviceId': senderDeviceId,
      'recordCount': wireRecords.length,
      'chunkCount': chunks.length,
      'totalBytes': totalBytes,
      'companyNames': companyNames,
      if (maxPreparedUpdatedAtMs > 0)
        'maxPreparedUpdatedAtMs': maxPreparedUpdatedAtMs,
    });

    return _BuiltPackage(
      recordCount: wireRecords.length,
      chunkCount: chunks.length,
      timestamp: now,
      expiresAt: expiresAt,
      totalBytes: totalBytes,
      companyNames: companyPreview.take(12).toList(),
    );
  }

  static Future<DeviceTransferReceiveResult> receiveOnThisDevice(
    String userId,
  ) async {
    final snap = await _transferRef(userId).get();
    if (!snap.exists) {
      throw StateError('Nessun pacchetto di trasferimento disponibile.');
    }

    final meta = DeviceTransferMeta.fromFirestore(snap.data() ?? {});
    if (!meta.isReceivable) {
      if (meta.isPrepared) {
        throw StateError(
          'Il mittente non ha ancora avviato l\'invio. Attendi sulla pagina Sincronizza dell\'altro dispositivo.',
        );
      }
      throw StateError('Nessun trasferimento in attesa.');
    }
    if (meta.isExpired) {
      await _deleteRemotePackage(userId);
      throw StateError('Il pacchetto è scaduto. Richiedi un nuovo invio.');
    }

    final localDeviceId = await DevelopSyncDevice.id();
    if (meta.senderDeviceId == localDeviceId) {
      throw StateError(
        'Hai inviato tu questo pacchetto. Attendi che l\'altro dispositivo '
        'tocchi «Ricevi dati».',
      );
    }

    final imported = <Map<String, dynamic>>[];
    Map<String, String> appMeta = {};
    Map<String, dynamic> publicUsage = {};

    for (var i = 0; i < meta.chunkCount; i++) {
      final chunkSnap = await _chunksRef(userId).doc('$i').get();
      if (!chunkSnap.exists) {
        throw StateError('Pacchetto incompleto (chunk $i mancante).');
      }
      final encrypted = chunkSnap.data()?['payload'] as String?;
      if (encrypted == null || encrypted.isEmpty) {
        throw StateError('Chunk $i non valido.');
      }

      final decoded = await DevelopSyncCrypto.decryptPayload(userId, encrypted);
      final safe = FirestoreJsonCodec.decodeMap(decoded);
      final records = safe['records'];
      if (records is List) {
        for (final item in records) {
          if (item is Map<String, dynamic>) {
            imported.add(item);
          } else if (item is Map) {
            imported.add(Map<String, dynamic>.from(item));
          }
        }
      }
      if (i == 0) {
        final metaRaw = safe['appMeta'];
        if (metaRaw is Map) {
          appMeta = metaRaw.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          );
        }
        final usageRaw = safe['publicUsage'];
        if (usageRaw is Map<String, dynamic>) {
          publicUsage = usageRaw;
        } else if (usageRaw is Map) {
          publicUsage = Map<String, dynamic>.from(usageRaw);
        }
      }
    }

    for (final record in imported) {
      final collection = record['collection'] as String?;
      final id = record['id'] as String?;
      if (collection == null || id == null) continue;
      final key = _companyNameKey(collection, id);
      final company = meta.companyNames[key];
      if (company == null) continue;
      final payload = record['payload'];
      if (payload is Map<String, dynamic>) {
        payload['companyName'] = company;
      } else if (payload is Map) {
        record['payload'] = {
          ...Map<String, dynamic>.from(payload),
          'companyName': company,
        };
      }
    }

    final receivedAt = DateTime.now();
    final sentAt = meta.sentAt;
    final totalBytes = meta.totalBytes;
    final syncBaselineMs = meta.syncBaselineMs ??
        meta.releasedAtMs ??
        receivedAt.millisecondsSinceEpoch;
    final applied = await LocalDatabaseService.instance.mergeTransferRecords(
      userId: userId,
      records: imported,
    );
    debugPrint(
      'DeviceTransferService: integrati $applied record per $userId',
    );

    var alignedAtMs = syncBaselineMs;
    for (final record in imported) {
      final ms = (record['updatedAtMs'] as num?)?.toInt() ?? 0;
      if (ms > alignedAtMs) alignedAtMs = ms;
    }

    for (final entry in appMeta.entries) {
      await LocalDatabaseService.instance.setMeta(entry.key, entry.value);
    }

    if (publicUsage.isNotEmpty) {
      await _writePublicUsage(userId, publicUsage);
    }

    await _deleteRemotePackage(userId);
    await _saveLastReceive(
      userId: userId,
      sentAt: sentAt,
      receivedAt: receivedAt,
      totalBytes: totalBytes,
    );
    await _saveLastSyncAt(userId, alignedAtMs);
    CreditCalcRepositorySetup.notifyDataChanged();
    await DevelopSyncCoordinator.afterDeviceTransferMerge(userId);

    return DeviceTransferReceiveResult(
      importedRecords: applied,
      sentAt: sentAt,
      receivedAt: receivedAt,
      totalBytes: totalBytes,
    );
  }

  static Future<Map<String, dynamic>> _readPublicUsage(
    DevicePublicUsageLocalDataAccess access,
  ) async {
    try {
      final counts = <String, int>{};
      for (final metric in PublicUsageMetric.values) {
        final value = await access.readMonthlyCount(metric);
        final field = publicUsageMonthlyStorageField(metric);
        if (field != null && value > 0) counts[field] = value;
      }
      final monthKey = DateTime.now();
      final key =
          '${monthKey.year}-${monthKey.month.toString().padLeft(2, '0')}';
      if (counts.isEmpty) return {};
      return {'monthKey': key, 'counts': counts};
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writePublicUsage(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'public_usage_local_v1_$userId',
        jsonEncode(data),
      );
      DevicePublicUsageLocalDataAccess(userId).notifyChanged();
    } catch (e) {
      debugPrint('DeviceTransferService: public usage non importato ($e)');
    }
  }
}

class _BuiltPackage {
  const _BuiltPackage({
    required this.recordCount,
    required this.chunkCount,
    required this.timestamp,
    required this.expiresAt,
    required this.totalBytes,
    required this.companyNames,
  });

  final int recordCount;
  final int chunkCount;
  final DateTime timestamp;
  final DateTime expiresAt;
  final int totalBytes;
  final List<String> companyNames;
}
