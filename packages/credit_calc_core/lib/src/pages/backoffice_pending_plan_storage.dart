import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/migrated_data_firestore_policy.dart';
import 'backoffice_pending_plan.dart';

/// Persistenza piani Riscontro backoffice (Firestore di default).
abstract class BackofficePendingPlanStorage {
  static BackofficePendingPlanStorage instance =
      FirestoreBackofficePendingPlanStorage();

  Stream<List<BackofficePendingPlan>> watchAll();

  Future<BackofficePendingSaveResult> save({
    String? existingId,
    required BackofficePendingPlanType type,
    required String creditorId,
    required String creditorName,
    required Map<String, dynamic> formData,
    required List<BackofficeSummaryRow> summaryRows,
    List<String> commissionDocIds = const [],
    String? companyName,
  });

  Future<void> delete(String id);

  Future<void> updateCommissionDocIds(String id, List<String> docIds);

  Future<void> markAcceptedManual(String id);
}

class FirestoreBackofficePendingPlanStorage
    implements BackofficePendingPlanStorage {
  CollectionReference<Map<String, dynamic>>? _collection() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('backoffice_pending_plans');
  }

  @override
  Stream<List<BackofficePendingPlan>> watchAll() {
    MigratedDataFirestorePolicy.assertFirestoreAccessAllowed();
    final collection = _collection();
    if (collection == null) {
      return const Stream.empty();
    }
    return collection
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map(BackofficePendingPlan.fromDoc).toList(),
        );
  }

  @override
  Future<BackofficePendingSaveResult> save({
    String? existingId,
    required BackofficePendingPlanType type,
    required String creditorId,
    required String creditorName,
    required Map<String, dynamic> formData,
    required List<BackofficeSummaryRow> summaryRows,
    List<String> commissionDocIds = const [],
    String? companyName,
  }) async {
    if (MigratedDataFirestorePolicy.firestoreAccessDisabled) {
      return const BackofficePendingSaveResult(
        errorMessage:
            'I dati Riscontro backoffice sono gestiti in locale su questo '
            'dispositivo.',
      );
    }

    final collection = _collection();
    if (collection == null) {
      return const BackofficePendingSaveResult(
        errorMessage: 'Devi essere autenticato per salvare il piano.',
      );
    }

    final docRef = existingId != null && existingId.isNotEmpty
        ? collection.doc(existingId)
        : collection.doc();

    final payload = {
      'type': type.storageKey,
      'creditorId': creditorId,
      'creditorName': creditorName,
      'updatedAt': FieldValue.serverTimestamp(),
      'formData': formData,
      'summaryRows': summaryRows.map((row) => row.toMap()).toList(),
      'commissionDocIds': commissionDocIds,
      if (companyName != null && companyName.trim().isNotEmpty)
        'companyName': companyName.trim(),
    };

    if (existingId == null || existingId.isEmpty) {
      payload['submittedAt'] = FieldValue.serverTimestamp();
    } else {
      payload['modifiedAt'] = FieldValue.serverTimestamp();
    }

    try {
      await docRef.set(payload, SetOptions(merge: true));
      return BackofficePendingSaveResult(id: docRef.id);
    } on FirebaseException catch (error) {
      return BackofficePendingSaveResult(
        errorMessage: _friendlyFirestoreError(error),
      );
    } catch (error) {
      return BackofficePendingSaveResult(
        errorMessage: 'Errore durante il salvataggio: $error',
      );
    }
  }

  @override
  Future<void> delete(String id) async {
    MigratedDataFirestorePolicy.assertWritesAllowed();
    final collection = _collection();
    if (collection == null) return;
    await collection.doc(id).delete();
  }

  @override
  Future<void> updateCommissionDocIds(String id, List<String> docIds) async {
    MigratedDataFirestorePolicy.assertWritesAllowed();
    final collection = _collection();
    if (collection == null) return;
    await collection.doc(id).set(
      {
        'commissionDocIds': docIds,
        'updatedAt': FieldValue.serverTimestamp(),
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedVia': BackofficeAcceptedVia.commission.storageKey,
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> markAcceptedManual(String id) async {
    MigratedDataFirestorePolicy.assertWritesAllowed();
    final collection = _collection();
    if (collection == null) return;
    await collection.doc(id).set(
      {
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedVia': BackofficeAcceptedVia.manual.storageKey,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static String _friendlyFirestoreError(FirebaseException error) {
    if (error.code == 'permission-denied') {
      return 'Permesso negato su Firestore. '
          'Le regole devono essere aggiornate sul progetto Firebase.';
    }
    return error.message ?? 'Errore Firestore (${error.code}).';
  }
}
