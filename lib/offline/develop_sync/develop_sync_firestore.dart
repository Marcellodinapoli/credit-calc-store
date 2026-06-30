import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_json_codec.dart';
import 'develop_sync_config.dart';
import 'develop_sync_crypto.dart';
import 'develop_sync_device.dart';
import 'develop_sync_wire_record.dart';
import 'models/develop_local_collection.dart';

/// Persistenza cloud del sync Sviluppa (relay cifrato per utente).
class DevelopSyncFirestore {
  DevelopSyncFirestore(this.userId);

  final String userId;
  static final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _records =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('develop_sync_records');

  DocumentReference<Map<String, dynamic>> get _meta =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('develop_sync')
          .doc('meta');

  Future<void> registerDevice() async {
    final deviceId = await DevelopSyncDevice.id();
    await _meta.set({
      'schemaVersion': DevelopSyncConfig.schemaVersion,
      'enabled': true,
      'devices': {
        deviceId: {
          'lastSeenAt': FieldValue.serverTimestamp(),
          'userAgent': 'creditcalc-store',
        },
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> touchDevice() async {
    final deviceId = await DevelopSyncDevice.id();
    await _meta.set({
      'devices': {
        deviceId: {
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> upsertWireRecord(DevelopSyncWireRecord wire) async {
    final collection = wire.collection;
    if (collection == null) return;

    final data = <String, dynamic>{
      'collection': collection.storageKey,
      'recordId': wire.recordId,
      'createdAtMs': wire.createdAtMs,
      'updatedAtMs': wire.updatedAtMs,
      'deviceId': wire.deviceId,
      'deleted': wire.deleted,
      'schemaVersion': DevelopSyncConfig.schemaVersion,
    };

    if (!wire.deleted && wire.payload != null) {
      final encoded = FirestoreJsonCodec.encodeMap(wire.payload!);
      data['payload'] = await DevelopSyncCrypto.encryptPayload(userId, encoded);
    } else {
      data['payload'] = FieldValue.delete();
    }

    await _records.doc(wire.documentId).set(data, SetOptions(merge: true));
  }

  Future<List<DevelopSyncWireRecord>> fetchRecordsUpdatedAfter(
    int updatedAfterMs,
  ) async {
    Query<Map<String, dynamic>> query = _records;
    if (updatedAfterMs > 0) {
      query = query.where('updatedAtMs', isGreaterThan: updatedAfterMs);
    }
    final snap = await query.get();
    return _decodeSnapshot(snap.docs);
  }

  Stream<List<DevelopSyncWireRecord>> watchRemoteChanges(int updatedAfterMs) {
    Query<Map<String, dynamic>> query = _records;
    if (updatedAfterMs > 0) {
      query = query.where('updatedAtMs', isGreaterThan: updatedAfterMs);
    }
    return query.snapshots().asyncMap((snap) async {
      final out = <DevelopSyncWireRecord>[];
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.removed) continue;
        final doc = change.doc;
        final data = doc.data();
        if (data == null) continue;
        final decoded = await _decodeDoc(doc.id, data);
        if (decoded != null) out.add(decoded);
      }
      return out;
    });
  }

  Future<List<DevelopSyncWireRecord>> _decodeSnapshot(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final out = <DevelopSyncWireRecord>[];
    for (final doc in docs) {
      final wire = await _decodeDoc(doc.id, doc.data());
      if (wire != null) out.add(wire);
    }
    return out;
  }

  Future<DevelopSyncWireRecord?> _decodeDoc(
    String docId,
    Map<String, dynamic> data,
  ) async {
    final wire = DevelopSyncWireRecord.fromFirestore(docId, data);
    if (wire.collection == null) return null;
    if (!storeDevelopSyncedCollections.contains(wire.collection)) return null;

    if (wire.deleted) return wire;

    final payloadRaw = data['payload'];
    if (payloadRaw is! String || payloadRaw.isEmpty) return null;
    final payload = await DevelopSyncCrypto.decryptPayload(userId, payloadRaw);
    return DevelopSyncWireRecord(
      collection: wire.collection,
      recordId: wire.recordId,
      createdAtMs: wire.createdAtMs,
      updatedAtMs: wire.updatedAtMs,
      deviceId: wire.deviceId,
      deleted: false,
      payload: FirestoreJsonCodec.decodeMap(payload),
    );
  }
}
