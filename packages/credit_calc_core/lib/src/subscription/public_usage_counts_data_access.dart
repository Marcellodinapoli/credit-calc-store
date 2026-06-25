import 'package:cloud_firestore/cloud_firestore.dart';

/// Conteggi per limiti piano (creditori e schemi provvigioni).
abstract class PublicUsageCountsDataAccess {
  static PublicUsageCountsDataAccess instance =
      FirestorePublicUsageCountsDataAccess();

  Future<int> countCreditors(String userId);

  Future<int> countCommissionSchemas(String userId);

  /// Pubblica i totali su Firebase per limiti e UI consumi (dati operativi restano locali).
  Future<void> publishTotals({
    required String userId,
    required int creditors,
    required int commissionSchemas,
  });
}

class FirestorePublicUsageCountsDataAccess
    implements PublicUsageCountsDataAccess {
  static final _firestore = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _totalsRef(String uid) =>
      _firestore
          .collection('users')
          .doc(uid)
          .collection('public_usage')
          .doc('totals');

  @override
  Future<int> countCreditors(String userId) async {
    final published = await _readPublishedCreditors(userId);
    return published ?? 0;
  }

  @override
  Future<int> countCommissionSchemas(String userId) async {
    final published = await _readPublishedCommissionSchemas(userId);
    return published ?? 0;
  }

  @override
  Future<void> publishTotals({
    required String userId,
    required int creditors,
    required int commissionSchemas,
  }) async {
    await _totalsRef(userId).set(
      {
        'creditors': creditors,
        'commissionSchemas': commissionSchemas,
        'deviceManaged': true,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<int?> _readPublishedCreditors(String userId) async {
    final snap = await _totalsRef(userId).get();
    if (!snap.exists || snap.data()?['deviceManaged'] != true) return null;
    return _readInt(snap.data()?['creditors']);
  }

  Future<int?> _readPublishedCommissionSchemas(String userId) async {
    final snap = await _totalsRef(userId).get();
    if (!snap.exists || snap.data()?['deviceManaged'] != true) return null;
    return _readInt(snap.data()?['commissionSchemas']);
  }

  static int _readInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }
}
