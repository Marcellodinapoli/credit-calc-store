import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Accesso dati per [CommissionEntryPage] (Firestore di default).
abstract class CommissionEntryDataAccess {
  static CommissionEntryDataAccess instance = FirestoreCommissionEntryDataAccess();

  Future<Map<String, dynamic>?> loadEntry(String entryId);

  Future<Map<String, dynamic>?> loadCreditorData(String creditorId);

  Future<void> saveEntry({
    required Map<String, dynamic> payload,
    String? entryId,
  });
}

class FirestoreCommissionEntryDataAccess implements CommissionEntryDataAccess {
  @override
  Future<Map<String, dynamic>?> loadEntry(String entryId) async {
    final doc = await FirebaseFirestore.instance
        .collection('calculations')
        .doc(entryId)
        .get();
    if (!doc.exists) return null;
    return doc.data();
  }

  @override
  Future<Map<String, dynamic>?> loadCreditorData(String creditorId) async {
    final doc = await FirebaseFirestore.instance
        .collection('creditors')
        .doc(creditorId)
        .get();
    if (!doc.exists) return null;
    return doc.data();
  }

  @override
  Future<void> saveEntry({
    required Map<String, dynamic> payload,
    String? entryId,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw StateError('Sessione scaduta');
    }

    final data = Map<String, dynamic>.from(payload);
    data['userId'] = userId;
    data['updatedAt'] = FieldValue.serverTimestamp();

    final collection = FirebaseFirestore.instance.collection('calculations');
    if (entryId != null && entryId.isNotEmpty) {
      await collection.doc(entryId).set(data, SetOptions(merge: true));
      return;
    }

    data['createdAt'] = FieldValue.serverTimestamp();
    await collection.add(data);
  }
}
