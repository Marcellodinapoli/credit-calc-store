import 'models/develop_local_collection.dart';

/// Record serializzato su Firestore per il sync multi-dispositivo.
class DevelopSyncWireRecord {
  const DevelopSyncWireRecord({
    required this.collection,
    required this.recordId,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.deviceId,
    required this.deleted,
    this.payload,
  });

  final DevelopLocalCollection? collection;
  final String recordId;
  final int createdAtMs;
  final int updatedAtMs;
  final String deviceId;
  final bool deleted;
  final Map<String, dynamic>? payload;

  String get documentId => '${collection?.storageKey ?? 'unknown'}::$recordId';

  factory DevelopSyncWireRecord.fromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    final collection = DevelopLocalCollectionCodec.fromStorageKey(
      data['collection'] as String?,
    );

    return DevelopSyncWireRecord(
      collection: collection,
      recordId: (data['recordId'] as String?) ?? docId.split('::').last,
      createdAtMs: _readMs(data['createdAtMs']),
      updatedAtMs: _readMs(data['updatedAtMs']),
      deviceId: (data['deviceId'] as String?) ?? '',
      deleted: data['deleted'] == true,
      payload: null,
    );
  }

  static int _readMs(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }
}
