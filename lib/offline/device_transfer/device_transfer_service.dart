import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../develop_sync/develop_sync_crypto.dart';
import '../develop_sync/develop_sync_device.dart';
import '../utils/firestore_json_codec.dart';
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

  static Future<DeviceTransferPeerState?> readPeerState(String userId) async {
    final localId = await DevelopSyncDevice.id();
    final snap = await _presenceRef(userId).get();
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
    if (local.neverSynced) return 'full';
    if (peer == null) return 'delta';
    if (peer.localRecordCount == 0) return 'full';
    if (peer.lastSyncAtMs != local.lastSyncAtMs) return 'full';
    return 'delta';
  }

  static Future<DeviceTransferSyncHint> adviseSync(String userId) async {
    final local = await readLocalState(userId);
    final peer = await readPeerState(userId);
    return DeviceTransferSyncAdvisor.advise(local: local, peer: peer);
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
    final meta = DeviceTransferMeta.fromFirestore(snap.data() ?? {});
    if (meta.isExpired) return null;
    if (meta.isPrepared || meta.isPending) return meta;
    return null;
  }

  static Future<bool> isActiveSender(String userId) async {
    final meta = await readTransferMeta(userId);
    if (meta == null || !meta.isPrepared) return false;
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
    await _presenceRef(userId).doc(deviceId).set({
      'lastSeenAtMs': DateTime.now().millisecondsSinceEpoch,
      'onSyncPage': true,
      'lastSyncAtMs': state.lastSyncAtMs,
      'maxUpdatedAtMs': state.maxUpdatedAtMs,
      'pendingChangeCount': state.pendingChangeCount,
      'localRecordCount': state.localRecordCount,
    }, SetOptions(merge: true));
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
    final transferMode = resolveTransferMode(local: local, peer: peer);

    if (transferMode == 'delta' && !local.hasPendingChanges) {
      throw StateError(
        'Nessun aggiornamento da inviare: i dispositivi risultano già allineati.',
      );
    }

    final built = await _buildAndUploadPackage(
      userId: userId,
      status: 'prepared',
      transferMode: transferMode,
      sinceMs: transferMode == 'delta' ? local.lastSyncAtMs : 0,
    );
    return DeviceTransferPrepareResult(
      recordCount: built.recordCount,
      totalBytes: built.totalBytes,
      companyNames: built.companyNames,
      preparedAt: built.timestamp,
      isDelta: transferMode == 'delta',
      pendingChanges: local.pendingChangeCount,
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
    await _saveLastSyncAt(userId, syncBaselineMs);

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
    required int sinceMs,
  }) async {
    await _deleteRemotePackage(userId);

    final db = LocalDatabaseService.instance;
    final rows = transferMode == 'delta'
        ? await db.recordsChangedSince(userId, sinceMs)
        : await db.listAllRecordsForUser(userId);
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
      if (transferMode == 'full' && isDeleted) continue;

      final company = _readCompanyName(payload);
      if (company != null) {
        companyNames[_companyNameKey(collection, id)] = company;
        companyPreview.add(company);
      }

      wireRecords.add({
        'collection': collection,
        'id': id,
        'payload': _payloadWithoutCompanyName(payload),
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
      'sinceMs': sinceMs > 0 ? sinceMs : null,
      'createdAtMs': now.millisecondsSinceEpoch,
      'expiresAtMs': expiresAt.millisecondsSinceEpoch,
      'senderDeviceId': senderDeviceId,
      'recordCount': wireRecords.length,
      'chunkCount': chunks.length,
      'totalBytes': totalBytes,
      'companyNames': companyNames,
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
    final int applied;

    if (meta.isFullTransfer) {
      await LocalDatabaseService.instance.clearUserData(userId);
      await LocalDatabaseService.instance.clearAppMeta(
        exceptKeys: const {
          'local_cipher_key_v1',
          'local_cipher_key_history_v1',
        },
      );
      await LocalDatabaseService.instance.importTransferRecords(
        userId: userId,
        records: imported,
      );
      applied = imported.length;
      debugPrint(
        'DeviceTransferService: importati $applied record (full) per $userId',
      );
    } else {
      applied = await LocalDatabaseService.instance.mergeTransferRecords(
        userId: userId,
        records: imported,
      );
      debugPrint(
        'DeviceTransferService: uniti $applied record (delta) per $userId',
      );
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
    await _saveLastSyncAt(userId, syncBaselineMs);
    CreditCalcRepositorySetup.notifyDataChanged();

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
