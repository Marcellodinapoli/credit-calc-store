import '../core/firestore_user_scope.dart';
import '../data/migrated_data_firestore_policy.dart';
import 'commission_collections_shared.dart';

/// Elenco incassi/provvigioni in tempo reale (Firestore di default).
abstract class CommissionEntriesDataAccess {
  static CommissionEntriesDataAccess instance =
      FirestoreCommissionEntriesDataAccess();

  Stream<List<CommissionEntryRecord>> watchCommissionEntries();
}

class FirestoreCommissionEntriesDataAccess
    implements CommissionEntriesDataAccess {
  @override
  Stream<List<CommissionEntryRecord>> watchCommissionEntries() {
    MigratedDataFirestorePolicy.assertFirestoreAccessAllowed();
    return FirestoreUserScope.userCalculations().snapshots().map((snap) {
      return CommissionCollectionsHelper.commissionEntries([
        for (final doc in snap.docs)
          CommissionEntryRecord(id: doc.id, data: doc.data()),
      ]);
    });
  }
}
