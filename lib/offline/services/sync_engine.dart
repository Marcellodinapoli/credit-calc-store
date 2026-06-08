import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sync_record_status.dart';
import '../utils/firestore_json_codec.dart';
import 'connectivity_service.dart';
import 'local_database_service.dart';
import 'mode_preferences_service.dart';
import 'session_service.dart';

class SyncRemoteCounts {
  final int creditors;
  final int calculations;

  const SyncRemoteCounts({
    required this.creditors,
    required this.calculations,
  });

  int get total => creditors + calculations;
}

class SyncRunResult {
  final bool success;
  final int pushed;
  final int pulled;
  final String? message;
  final SyncRemoteCounts? remoteCounts;

  const SyncRunResult({
    required this.success,
    this.pushed = 0,
    this.pulled = 0,
    this.message,
    this.remoteCounts,
  });

  factory SyncRunResult.failed(String message) =>
      SyncRunResult(success: false, message: message);
}

class SyncProgress {
  final String step;
  final double progress;

  const SyncProgress(this.step, this.progress);
}

/// Sincronizzazione iniziale e incrementale CreditCalc ↔ Firebase.
class SyncEngine {
  static const _syncedCollections = {'creditors', 'calculations'};
  SyncEngine({
    required this.userId,
    required this.modePrefs,
    required this.sessionService,
  });

  final String userId;
  final ModePreferencesService modePrefs;
  final SessionService sessionService;
  final _db = LocalDatabaseService.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<SyncRemoteCounts> probeRemoteCounts() async {
    final creditors = await _firestore
        .collection('creditors')
        .where('userId', isEqualTo: userId)
        .get();
    final calculations = await _firestore
        .collection('calculations')
        .where('userId', isEqualTo: userId)
        .get();
    return SyncRemoteCounts(
      creditors: creditors.docs.length,
      calculations: calculations.docs.length,
    );
  }

  Future<SyncRunResult> repairSync() async {
    await _db.clearUserData(userId);
    await modePrefs.resetInitialSyncFlag();
    return runSync();
  }

  Future<void> performInitialSync({
    void Function(SyncProgress progress)? onProgress,
  }) async {
    if (!await ConnectivityService.isOnline()) {
      throw StateError('Connessione internet richiesta per la prima sincronizzazione.');
    }

    onProgress?.call(const SyncProgress('Download creditori…', 0.1));
    late final QuerySnapshot<Map<String, dynamic>> creditors;
    late final QuerySnapshot<Map<String, dynamic>> calculations;
    try {
      creditors = await _firestore
          .collection('creditors')
          .where('userId', isEqualTo: userId)
          .get();

      onProgress?.call(const SyncProgress('Download pratiche…', 0.45));
      calculations = await _firestore
          .collection('calculations')
          .where('userId', isEqualTo: userId)
          .get();
    } on FirebaseException catch (e) {
      throw StateError(
        'Errore Firebase (${e.code}): ${e.message ?? 'impossibile leggere i dati.'}',
      );
    }

    onProgress?.call(const SyncProgress('Salvataggio locale…', 0.75));

    for (final doc in creditors.docs) {
      await _saveRemoteDoc(
        collection: 'creditors',
        id: doc.id,
        data: doc.data(),
      );
    }
    for (final doc in calculations.docs) {
      await _saveRemoteDoc(
        collection: 'calculations',
        id: doc.id,
        data: doc.data(),
      );
    }

    final total = creditors.docs.length + calculations.docs.length;
    final version = DateTime.now().millisecondsSinceEpoch.toString();
    await modePrefs.markInitialSyncComplete(
      recordCount: total,
      dataVersion: version,
    );
    onProgress?.call(const SyncProgress('Completata', 1));
  }

  Future<int> localRecordCount() => _localRecordCount();

  /// `true` se Firebase ha più dati di quelli presenti in copia locale.
  Future<bool> isBehindRemote() async {
    if (!await ConnectivityService.isOnline()) return false;
    final localCount = await _localRecordCount();
    if (localCount == 0) return true;
    try {
      final remote = await probeRemoteCounts();
      return remote.total > localCount;
    } catch (_) {
      return false;
    }
  }

  /// Sync completa: prima sync se necessaria, altrimenti push + pull incrementale.
  Future<SyncRunResult> runSync() async {
    if (!await ConnectivityService.isOnline()) {
      return SyncRunResult.failed('Connessione non disponibile.');
    }

    await sessionService.ensureLocalSession();

    if (!await sessionService.holdsActiveSession()) {
      return SyncRunResult.failed(
        'La sessione è attiva su un altro dispositivo. '
        'Riapri CreditCalc qui e scegli «Continua qui».',
      );
    }

    final initialDone = await modePrefs.isInitialSyncDoneLocally();
    final localCount = await _localRecordCount();
    SyncRemoteCounts remote;
    try {
      remote = await probeRemoteCounts();
    } catch (e) {
      return SyncRunResult.failed(
        'Impossibile leggere i dati su Firebase. Verifica la connessione.',
      );
    }

    final needsFullDownload = !initialDone || (localCount == 0 && remote.total > 0);
    if (needsFullDownload) {
      try {
        await performInitialSync();
        final downloaded = await _localRecordCount();
        return SyncRunResult(
          success: true,
          pulled: downloaded,
          remoteCounts: remote,
          message: downloaded == 0
              ? 'Firebase: ${remote.creditors} creditori, ${remote.calculations} pratiche. '
                  'Salvati localmente: $downloaded.'
              : 'Download completato: $downloaded record '
                  '(Firebase: ${remote.total}).',
        );
      } catch (e) {
        return SyncRunResult.failed(
          e.toString().replaceFirst('StateError: ', ''),
        );
      }
    }

    if (remote.total > localCount) {
      try {
        final pulled = await _pullRemoteUpdates();
        await modePrefs.updateLastSyncAt();
        final updatedLocal = await _localRecordCount();
        return SyncRunResult(
          success: true,
          pulled: pulled,
          remoteCounts: remote,
          message: pulled == 0
              ? 'Copia locale aggiornata: $updatedLocal record '
                  '(Firebase: ${remote.total}).'
              : 'Scaricati $pulled aggiornamenti da Firebase '
                  '(locali: $updatedLocal / ${remote.total}).',
        );
      } catch (e) {
        return SyncRunResult.failed(
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }

    try {
      return await syncPendingChanges();
    } catch (e) {
      return SyncRunResult.failed(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<int> _localRecordCount() async {
    final creditors = await _db.recordsForUser(
      userId: userId,
      collection: 'creditors',
    );
    final calculations = await _db.recordsForUser(
      userId: userId,
      collection: 'calculations',
    );
    int count = 0;
    for (final row in creditors) {
      if (row['payload']['_deleted'] != true) count++;
    }
    for (final row in calculations) {
      if (row['payload']['_deleted'] != true) count++;
    }
    return count;
  }

  Future<SyncRunResult> syncPendingChanges() async {
    if (!await ConnectivityService.isOnline()) {
      return SyncRunResult.failed('Connessione non disponibile.');
    }
    if (!await sessionService.holdsActiveSession()) {
      return SyncRunResult.failed(
        'La sessione è attiva su un altro dispositivo.',
      );
    }

    var pushed = 0;
    var pulled = 0;

    final pending = await _db.pendingRecords(userId);
    for (final row in pending) {
      final collection = row['collection'] as String;
      if (!_syncedCollections.contains(collection)) continue;
      final id = row['id'] as String;
      final payload = FirestoreJsonCodec.decodeMap(
        Map<String, dynamic>.from(row['payload'] as Map),
      );
      if (payload['_deleted'] == true) {
        await _firestore.collection(collection).doc(id).delete();
        await _db.deleteRecord(collection: collection, id: id);
        pushed++;
        continue;
      }

      payload['userId'] = userId;
      payload['updatedAt'] = FieldValue.serverTimestamp();
      payload.remove('_deleted');

      final ref = _firestore.collection(collection).doc(id);
      final remote = await ref.get();
      if (remote.exists) {
        final remoteUpdated = remote.data()?['updatedAt'];
        final localServerUpdated = row['serverUpdatedAt'] as DateTime?;
        if (remoteUpdated is Timestamp &&
            localServerUpdated != null &&
            remoteUpdated.toDate().isAfter(localServerUpdated)) {
          await _saveRemoteDoc(
            collection: collection,
            id: id,
            data: remote.data()!,
            conflict: true,
          );
          continue;
        }
      }

      await ref.set(payload, SetOptions(merge: true));
      final fresh = await ref.get();
      final updated = fresh.data()?['updatedAt'];
      await _db.markSynced(
        collection: collection,
        id: id,
        serverUpdatedAt:
            updated is Timestamp ? updated.toDate() : DateTime.now(),
      );
      pushed++;
    }

    pulled = await _pullRemoteUpdates();
    await modePrefs.updateLastSyncAt();
    final remote = await probeRemoteCounts();
    return SyncRunResult(
      success: true,
      pushed: pushed,
      pulled: pulled,
      remoteCounts: remote,
      message: pushed == 0 && pulled == 0
          ? 'Nessuna modifica. Su Firebase: ${remote.creditors} creditori, '
              '${remote.calculations} pratiche. Locali: ${await _localRecordCount()}.'
          : 'Sincronizzazione completata (↑$pushed ↓$pulled).',
    );
  }

  Future<int> _pullRemoteUpdates() async {
    var pulled = 0;
    final creditors = await _firestore
        .collection('creditors')
        .where('userId', isEqualTo: userId)
        .get();
    for (final doc in creditors.docs) {
      if (await _mergeRemoteIfNewer(
        collection: 'creditors',
        id: doc.id,
        data: doc.data(),
      )) {
        pulled++;
      }
    }

    final calculations = await _firestore
        .collection('calculations')
        .where('userId', isEqualTo: userId)
        .get();
    for (final doc in calculations.docs) {
      if (await _mergeRemoteIfNewer(
        collection: 'calculations',
        id: doc.id,
        data: doc.data(),
      )) {
        pulled++;
      }
    }
    return pulled;
  }

  Future<bool> _mergeRemoteIfNewer({
    required String collection,
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final local = await _db.recordById(collection: collection, id: id);
    if (local == null) {
      await _saveRemoteDoc(collection: collection, id: id, data: data);
      return true;
    }
    if (local['syncStatus'] == SyncRecordStatus.pending) return false;

    final remoteUpdated = data['updatedAt'];
    final localServerUpdated = local['serverUpdatedAt'] as DateTime?;
    if (remoteUpdated is! Timestamp) {
      await _saveRemoteDoc(collection: collection, id: id, data: data);
      return true;
    }
    if (localServerUpdated == null ||
        remoteUpdated.toDate().isAfter(localServerUpdated)) {
      await _saveRemoteDoc(collection: collection, id: id, data: data);
      return true;
    }
    return false;
  }

  /// Applica una modifica remota in tempo reale (listener Firestore).
  Future<bool> applyRemoteChange({
    required String collection,
    required DocumentChangeType changeType,
    required String id,
    required Map<String, dynamic>? data,
  }) async {
    if (!_syncedCollections.contains(collection)) return false;

    if (changeType == DocumentChangeType.removed) {
      final local = await _db.recordById(collection: collection, id: id);
      if (local == null) return false;
      if (local['syncStatus'] == SyncRecordStatus.pending) return false;
      await _db.deleteRecord(collection: collection, id: id);
      return true;
    }

    if (data == null) return false;
    return _mergeRemoteIfNewer(collection: collection, id: id, data: data);
  }

  Future<void> _saveRemoteDoc({
    required String collection,
    required String id,
    required Map<String, dynamic> data,
    bool conflict = false,
  }) async {
    final created = data['createdAt'];
    final updated = data['updatedAt'];
    await _db.upsertRecord(
      collection: collection,
      id: id,
      userId: userId,
      payload: data,
      createdAt: created is Timestamp ? created.toDate() : DateTime.now(),
      updatedAt: updated is Timestamp ? updated.toDate() : DateTime.now(),
      serverUpdatedAt: updated is Timestamp ? updated.toDate() : null,
      syncStatus:
          conflict ? SyncRecordStatus.conflict : SyncRecordStatus.synced,
      origin: 'firebase',
    );
  }
}
