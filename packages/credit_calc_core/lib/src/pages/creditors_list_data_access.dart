import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/firestore_user_scope.dart';
import '../data/migrated_data_firestore_policy.dart';

class CreditorRecord {
  final String id;
  final Map<String, dynamic> data;

  const CreditorRecord({required this.id, required this.data});
}

/// Elenco e persistenza creditori (Firestore di default).
abstract class CreditorsListDataAccess {
  static CreditorsListDataAccess instance = FirestoreCreditorsListDataAccess();

  Stream<List<CreditorRecord>> watchCreditors();

  String newCreditorId();

  Future<Map<String, dynamic>?> loadCreditor(String creditorId);

  Future<bool> creditorExists(String creditorId);

  Future<void> saveCreditor({
    required String creditorId,
    required Map<String, dynamic> data,
  });

  Future<void> deleteCreditor(String creditorId);
}

class FirestoreCreditorsListDataAccess implements CreditorsListDataAccess {
  @override
  Stream<List<CreditorRecord>> watchCreditors() {
    MigratedDataFirestorePolicy.assertFirestoreAccessAllowed();
    return FirestoreUserScope.creditorsOrdered().snapshots().map((snap) {
      final docs = FirestoreUserScope.sortCreditorsByCreatedAt(snap.docs);
      return [
        for (final doc in docs)
          CreditorRecord(id: doc.id, data: doc.data()),
      ];
    });
  }

  @override
  String newCreditorId() {
    MigratedDataFirestorePolicy.assertFirestoreAccessAllowed();
    return FirebaseFirestore.instance.collection('creditors').doc().id;
  }

  @override
  Future<Map<String, dynamic>?> loadCreditor(String creditorId) async {
    MigratedDataFirestorePolicy.assertFirestoreAccessAllowed();
    final doc = await FirebaseFirestore.instance
        .collection('creditors')
        .doc(creditorId)
        .get();
    if (!doc.exists) return null;
    return doc.data();
  }

  @override
  Future<bool> creditorExists(String creditorId) async {
    MigratedDataFirestorePolicy.assertFirestoreAccessAllowed();
    final doc = await FirebaseFirestore.instance
        .collection('creditors')
        .doc(creditorId)
        .get();
    return doc.exists;
  }

  @override
  Future<void> saveCreditor({
    required String creditorId,
    required Map<String, dynamic> data,
  }) async {
    MigratedDataFirestorePolicy.assertWritesAllowed();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw StateError('Sessione scaduta');
    }

    final ref =
        FirebaseFirestore.instance.collection('creditors').doc(creditorId);
    final existing = await ref.get();
    final payload = Map<String, dynamic>.from(data)
      ..['userId'] = userId
      ..['updatedAt'] = FieldValue.serverTimestamp();

    if (!existing.exists) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    await ref.set(payload, SetOptions(merge: true));
  }

  @override
  Future<void> deleteCreditor(String creditorId) async {
    MigratedDataFirestorePolicy.assertWritesAllowed();
    if (creditorId.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('creditors')
        .doc(creditorId)
        .delete();
  }
}
