import 'package:cloud_firestore/cloud_firestore.dart';

/// Letture Firestore dal server — ignora la cache locale del dispositivo.
abstract final class FirestoreServerReads {
  static const getOptions = GetOptions(source: Source.server);

  static Future<DocumentSnapshot<Map<String, dynamic>>> get(
    DocumentReference<Map<String, dynamic>> ref,
  ) {
    return ref.get(getOptions);
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> getQuery(
    Query<Map<String, dynamic>> query,
  ) {
    return query.get(getOptions);
  }

  /// Prima lettura dal server, poi solo aggiornamenti confermati dal server.
  static Stream<DocumentSnapshot<Map<String, dynamic>>> watch(
    DocumentReference<Map<String, dynamic>> ref,
  ) async* {
    yield await get(ref);
    await for (final snap in ref.snapshots(includeMetadataChanges: true)) {
      if (!snap.metadata.isFromCache) {
        yield snap;
      }
    }
  }

  /// Come [watch] ma per query (es. incassi/provvigioni utente).
  static Stream<QuerySnapshot<Map<String, dynamic>>> watchQuery(
    Query<Map<String, dynamic>> query,
  ) async* {
    yield await getQuery(query);
    await for (final snap in query.snapshots(includeMetadataChanges: true)) {
      if (!snap.metadata.isFromCache) {
        yield snap;
      }
    }
  }
}
