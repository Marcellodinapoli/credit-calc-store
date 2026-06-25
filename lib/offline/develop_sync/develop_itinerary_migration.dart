import 'package:flutter/foundation.dart';

import 'develop_sync_sqlite_store.dart';

/// Import legacy da Firestore disabilitato: i dati con ragione sociale restano
/// solo in locale / sync cifrato.
abstract final class DevelopItineraryMigration {
  static Future<void> importFromFirestoreIfEmpty(
    DevelopSyncSqliteStore store,
  ) async {
    debugPrint(
      'DevelopItineraryMigration: import Firestore legacy disabilitato (GDPR).',
    );
  }
}
